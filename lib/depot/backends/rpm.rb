# frozen_string_literal: true

require "fileutils"
require "time"
require_relative "../desktop_entry"
require_relative "../paths"
require_relative "../result"
require_relative "../packages/rpm"
require_relative "../util"
require_relative "support"

module Depot
  module Backends
    class Rpm
      include Support

      def initialize(store:)
        @store = store
      end

      def install(inspection, settings: {})
        return Result.err("RPM backend cannot install #{inspection.format}") unless inspection.rpm?

        Paths.ensure_base_dirs
        package = RpmPackage.new(inspection.input)
        return Result.err("Invalid RPM package.") unless package.valid?

        app_id = Util.unique_id(Util.slug("#{package.display_name}-#{package.version_label}"), @store.ids)
        app_dir = File.join(Paths.apps_dir, app_id)
        root_dir = File.join(app_dir, "root")
        FileUtils.mkdir_p(app_dir)

        package.extract_to(root_dir)

        desktop_source = package.primary_desktop_entry
        desktop_contents = desktop_source && read_extracted_entry(root_dir, desktop_source)
        display_name = desktop_name(desktop_contents) || package.display_name
        preferred_icon = desktop_contents&.[]( /^Icon=(.+)$/, 1)&.strip
        icon_name = install_icons(package, root_dir, app_id, preferred_icon)
        executable = executable_for(package, root_dir, desktop_contents)

        desktop_path = nil
        if settings.fetch("desktop_integration", true) && executable
          desktop_path = File.join(Paths.desktop_entries_dir, "depot-#{app_id}.desktop")
          contents = desktop_contents ? rewrite_desktop(desktop_contents, root_dir, app_id, display_name, icon_name) : generated_desktop(app_id, display_name, executable, icon_name)
          File.write(desktop_path, contents)
        end

        warnings = inspection.warnings + portable_warnings(package, executable, desktop_source)
        manifest = {
          "schema_version" => 1,
          "app_id" => app_id,
          "display_name" => display_name,
          "default_display_name" => display_name,
          "backend" => "rpm-portable",
          "install_source" => File.expand_path(inspection.input),
          "source_sha256" => inspection.sha256,
          "source_size" => inspection.size,
          "installed_executable" => executable,
          "desktop_entry" => desktop_path,
          "icons" => installed_icon_paths(app_id, preferred_icon),
          "default_icon_name" => icon_name,
          "created_files" => [desktop_path].compact + installed_icon_paths(app_id, preferred_icon),
          "created_dirs" => [app_dir],
          "installed_at" => Time.now.utc.iso8601,
          "package" => package.package_fields.merge("Requires" => package.requires),
          "desktop_source" => desktop_source,
          "portable_root" => root_dir,
          "permissions" => {
            "executable" => executable ? File.executable?(executable) : false,
            "requires_sudo" => false,
            "writes_outside_depot" => false,
            "notes" => ["RPM payload extracted user-locally. RPM scriptlets were not executed."]
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
      rescue RpmPackage::FormatError, SystemCallError => e
        Result.err("RPM install failed: #{e.message}")
      end

      private

      def read_extracted_entry(root_dir, entry)
        path = File.join(root_dir, entry)
        return nil unless File.file?(path)

        File.read(path)
      end

      def desktop_name(contents)
        return nil unless contents

        line = contents.lines.find { |candidate| candidate.start_with?("Name=") }
        line&.split("=", 2)&.last&.strip
      rescue SystemCallError
        nil
      end

      def executable_for(package, root_dir, desktop_contents)
        exec_line = desktop_contents&.lines&.find { |line| line.start_with?("Exec=") }
        command = exec_line&.split("=", 2)&.last.to_s.strip
        rewritten = rewrite_exec_value(command, root_dir)
        first = first_exec_token(rewritten)
        return first if first && File.exist?(first)

        package.executable_candidates.map { |entry| File.join(root_dir, entry) }.find { |path| File.file?(path) && File.executable?(path) }
      rescue SystemCallError
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
          icon_install_names(app_id, preferred).each do |name|
            FileUtils.cp(source, File.join(target_dir, "#{name}#{ext}"))
          end
        end
        icon_paths(app_id).any? ? app_id : nil
      end

      def fallback_icon_entries(package, preferred)
        preferred_base = File.basename(preferred.to_s, ".*")
        candidates = package.image_entries
        scored = candidates.select do |entry|
          base = File.basename(entry, ".*")
          entry.match?(/(^|\/)(icon|logo|app|code)[^\/]*\.(png|svg|xpm)\z/i) ||
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
          entry.match?(/(^|\/)(icon|logo|app|code)[^\/]*\.(png|svg|xpm)\z/i) ? 0 : 1,
          -entry.length
        ]
      end

      def icon_theme_size(entry, source)
        match = entry.match(RpmPackage::HICOLOR_ICON_PATH)
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

      def installed_icon_paths(app_id, preferred)
        icon_install_names(app_id, preferred).flat_map do |name|
          Dir.glob(File.join(Paths.icon_root, "*", "apps", "#{name}.{png,svg,xpm}"), File::FNM_EXTGLOB)
        end.uniq
      end

      def icon_install_names(app_id, preferred)
        names = [app_id]
        preferred = preferred.to_s
        names << preferred if preferred.match?(/\A[a-zA-Z0-9_.-]+\z/)
        names.uniq
      end

      def portable_warnings(package, executable, desktop_source)
        warnings = ["Depot installed this RPM in portable extraction mode and did not use rpm, dnf, zypper, sudo, or root scriptlets."]
        warnings << "RPM scriptlets were found and were not executed: #{package.scriptlets.join(", ")}." unless package.scriptlets.empty?
        warnings << "No desktop launcher was found; Depot generated one." unless desktop_source
        warnings << "No executable could be confidently selected." unless executable
        warnings
      end

    end
  end
end
