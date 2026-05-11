# frozen_string_literal: true

require "fileutils"
require "time"
require_relative "../packages/archive"
require_relative "../desktop_entry"
require_relative "../paths"
require_relative "../result"
require_relative "../util"
require_relative "support"

module Depot
  module Backends
    class Archive
      include Support

      def initialize(store:)
        @store = store
      end

      def install(inspection, settings: {})
        return Result.err("Archive backend cannot install #{inspection.format}") unless inspection.archive?

        Paths.ensure_base_dirs
        package = ArchivePackage.new(inspection.input)
        return Result.err("Unsupported or invalid archive.") unless package.valid?

        app_id = Util.unique_id(Util.slug(inspection.display_name), @store.ids)
        app_dir = File.join(Paths.apps_dir, app_id)
        root_dir = File.join(app_dir, "root")
        FileUtils.mkdir_p(app_dir)

        package.extract_to(root_dir)

        desktop_source = package.primary_desktop_entry
        display_name = desktop_name(package, desktop_source) || package.display_name
        preferred_icon = desktop_source && package.read_entry(desktop_source)[/^Icon=(.+)$/, 1]&.strip
        icon_name = install_icons(package, root_dir, app_id, preferred_icon)
        executable = executable_for(package, root_dir, desktop_source)

        desktop_path = nil
        if settings.fetch("desktop_integration", true) && executable
          desktop_path = File.join(Paths.desktop_entries_dir, "depot-#{app_id}.desktop")
          contents = desktop_source ? rewrite_desktop(package.read_entry(desktop_source), root_dir, app_id, display_name, icon_name) : generated_desktop(app_id, display_name, executable, icon_name)
          File.write(desktop_path, contents)
        end

        warnings = inspection.warnings + portable_warnings(package, executable, desktop_source)
        manifest = {
          "schema_version" => 1,
          "app_id" => app_id,
          "display_name" => display_name,
          "default_display_name" => display_name,
          "backend" => "archive-portable",
          "install_source" => File.expand_path(inspection.input),
          "source_sha256" => inspection.sha256,
          "source_size" => inspection.size,
          "installed_executable" => executable,
          "desktop_entry" => desktop_path,
          "icons" => icon_paths(app_id),
          "default_icon_name" => icon_name,
          "created_files" => [desktop_path].compact + icon_paths(app_id),
          "created_dirs" => [app_dir],
          "installed_at" => Time.now.utc.iso8601,
          "archive" => {
            "format" => package.format,
            "root" => package.common_root,
            "desktop_source" => desktop_source
          },
          "portable_root" => root_dir,
          "permissions" => {
            "executable" => executable ? File.executable?(executable) : false,
            "requires_sudo" => false,
            "writes_outside_depot" => false,
            "notes" => ["Archive extracted user-locally. Installer scripts were not executed."]
          },
          "sandbox" => {
            "enabled" => false,
            "preference" => settings.fetch("sandbox_preference", "ask")
          },
          "update" => {
            "mechanism" => "manual",
            "source" => File.expand_path(inspection.input)
          },
          "warnings" => warnings
        }

        manifest_path = @store.write(manifest)
        refresh_desktop_caches if settings.fetch("desktop_integration", true)
        Result.ok(manifest.merge("manifest_path" => manifest_path), warnings:)
      rescue ArchivePackage::FormatError, SystemCallError => e
        Result.err("Archive install failed: #{e.message}")
      end

      private

      def desktop_name(package, entry)
        return nil unless entry

        line = package.read_entry(entry).lines.find { |candidate| candidate.start_with?("Name=") }
        line&.split("=", 2)&.last&.strip
      rescue ArchivePackage::FormatError
        nil
      end

      def executable_for(package, root_dir, desktop_entry)
        exec_line = desktop_entry && package.read_entry(desktop_entry).lines.find { |line| line.start_with?("Exec=") }
        command = exec_line&.split("=", 2)&.last.to_s.strip
        rewritten = rewrite_exec_value(command, root_dir)
        first = first_exec_token(rewritten)
        return first if first && File.exist?(first)

        candidates = package.executable_candidates.map { |entry| File.join(root_dir, entry) }
        candidates.find { |path| File.file?(path) && File.executable?(path) } ||
          candidates.find { |path| File.file?(path) }
      rescue ArchivePackage::FormatError
        nil
      end

      def generated_desktop(app_id, display_name, executable, icon_name)
        DesktopEntry.new(app_id:, name: display_name, exec_path: executable, icon_name:).contents
      end

      def rewrite_desktop(contents, root_dir, app_id, display_name, icon_name)
        seen_depot_id = false
        current_group = nil
        lines = []
        contents.lines.each do |line|
          if line.start_with?("[")
            lines << "X-Depot-AppID=#{app_id}\n" if current_group == "[Desktop Entry]" && !seen_depot_id
            current_group = line.strip
          end

          lines << if line.start_with?("Name=") && current_group == "[Desktop Entry]"
                     "Name=#{display_name}\n"
                   elsif line.match?(/\AExec=/)
                     "Exec=#{rewrite_exec_value(line.split("=", 2).last.strip, root_dir)}\n"
                   elsif line.match?(/\ATryExec=/)
                     "TryExec=#{rewrite_exec_value(line.split("=", 2).last.strip, root_dir)}\n"
                   elsif line.start_with?("Icon=")
                     icon_name ? "Icon=#{icon_name}\n" : line
                   elsif line.start_with?("X-Depot-AppID=")
                     seen_depot_id = true
                     "X-Depot-AppID=#{app_id}\n"
                   else
                     line
                   end
        end
        lines << "X-Depot-AppID=#{app_id}\n" if current_group == "[Desktop Entry]" && !seen_depot_id
        lines.join
      end

      def rewrite_exec_value(value, root_dir)
        token, rest = split_exec(value)
        return value if token.to_s.empty?

        mapped = if token.start_with?("/")
                   File.join(root_dir, token.delete_prefix("/"))
                 elsif token.include?("/")
                   File.join(root_dir, token)
                 else
                   candidate = find_executable(root_dir, token)
                   candidate || token
                 end
        "#{Util.desktop_exec_quote(mapped)}#{rest}"
      end

      def split_exec(value)
        if value.start_with?('"')
          closing = value.index('"', 1)
          return [value[1...closing], value[(closing + 1)..].to_s] if closing
        end
        token, rest = value.split(/\s+/, 2)
        [token, rest ? " #{rest}" : ""]
      end

      def first_exec_token(value)
        token, = split_exec(value)
        token
      end

      def find_executable(root_dir, token)
        Dir.glob(File.join(root_dir, "**", token)).find { |path| File.file?(path) && File.executable?(path) }
      end

      def install_icons(package, root_dir, app_id, preferred)
        icons = package.icon_entries
        icons = fallback_icon_entries(package, preferred) if icons.empty?
        icons.sort_by { |entry| icon_score(entry, preferred) }.first(8).each do |entry|
          ext = File.extname(entry).downcase
          next unless [".png", ".svg", ".xpm"].include?(ext)

          source = File.join(root_dir, entry)
          next unless File.file?(source)

          target_dir = File.join(Paths.icon_root, icon_theme_size(entry, source), "apps")
          FileUtils.mkdir_p(target_dir)
          FileUtils.cp(source, File.join(target_dir, "#{app_id}#{ext}"))
        end
        icon_paths(app_id).any? ? app_id : nil
      end

      def fallback_icon_entries(package, preferred)
        preferred_base = File.basename(preferred.to_s, ".*")
        candidates = package.image_entries
        scored = candidates.select do |entry|
          base = File.basename(entry, ".*")
          entry.match?(/(^|\/)(icon|logo|app)[^\/]*\.(png|svg|xpm)\z/i) ||
            (!preferred_base.empty? && (base == preferred_base || entry.downcase.include?(preferred_base.downcase)))
        end
        scored.empty? ? candidates : scored
      end

      def icon_score(entry, preferred)
        base = File.basename(entry, ".*")
        [
          preferred.to_s.empty? || base != preferred ? 1 : 0,
          entry.include?("/256x256/") ? 0 : 1,
          entry.include?("/512x512/") ? 0 : 1,
          entry.match?(/(^|\/)(icon|logo|app)[^\/]*\.(png|svg|xpm)\z/i) ? 0 : 1,
          -entry.length
        ]
      end

      def icon_theme_size(entry, source)
        match = entry.match(ArchivePackage::HICOLOR_ICON_PATH)
        return match[1] if match
        return "scalable" if File.extname(entry).downcase == ".svg"
        return png_size(source) if File.extname(entry).downcase == ".png"

        "256x256"
      end

      def png_size(path)
        File.open(path, "rb") do |file|
          header = file.read(24)
          return "256x256" unless header&.start_with?("\x89PNG\r\n\x1A\n".b)

          width, height = header.byteslice(16, 8).unpack("NN")
          return "256x256" if width.to_i <= 0 || height.to_i <= 0

          "#{width}x#{height}"
        end
      rescue SystemCallError
        "256x256"
      end

      def icon_paths(app_id)
        Dir.glob(File.join(Paths.icon_root, "*", "apps", "#{app_id}.{png,svg,xpm}"), File::FNM_EXTGLOB)
      end

      def portable_warnings(package, executable, desktop_source)
        warnings = ["Depot installed this archive in portable extraction mode and did not run installer scripts."]
        warnings << "No desktop launcher was found; Depot generated one." unless desktop_source
        warnings << "No executable could be confidently selected." unless executable
        warnings << "Installer-like scripts were found and were not executed: #{package.script_entries.first(6).join(", ")}." unless package.script_entries.empty?
        warnings << "Source/build markers were found: #{package.source_markers.join(", ")}." unless package.source_markers.empty?
        warnings
      end

    end
  end
end
