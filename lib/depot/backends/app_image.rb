# frozen_string_literal: true

require "fileutils"
require "open3"
require "shellwords"
require "tmpdir"
require "timeout"
require "time"
require_relative "../desktop_entry"
require_relative "../paths"
require_relative "../result"
require_relative "../util"

module Depot
  module Backends
    class AppImage
      EXTRACTION_TIMEOUT_SECONDS = 25

      def initialize(store:)
        @store = store
      end

      def install(inspection, settings: {})
        return Result.err("AppImage backend cannot install #{inspection.format}") unless inspection.appimage?

        Paths.ensure_base_dirs

        taken = @store.ids
        app_id = Util.unique_id(Util.slug(inspection.display_name), taken)
        app_dir = File.join(Paths.apps_dir, app_id)
        FileUtils.mkdir_p(app_dir)

        installed_name = File.basename(inspection.input)
        installed_path = File.join(app_dir, installed_name)
        FileUtils.cp(inspection.input, installed_path)
        FileUtils.chmod(File.stat(installed_path).mode | 0o111, installed_path)

        metadata = extract_metadata(installed_path, app_id)
        display_name = metadata.fetch("name", inspection.display_name)
        icon_paths = metadata.fetch("icons", [])
        icon_name = icon_paths.any? ? app_id : nil

        desktop_path = nil
        if settings.fetch("desktop_integration", true)
          desktop_path = File.join(Paths.desktop_entries_dir, "depot-#{app_id}.desktop")
          entry = DesktopEntry.new(app_id:, name: display_name, exec_path: installed_path, icon_name:)
          File.write(desktop_path, entry.contents)
        end

        manifest = {
          "schema_version" => 1,
          "app_id" => app_id,
          "display_name" => display_name,
          "default_display_name" => display_name,
          "backend" => "appimage",
          "install_source" => File.expand_path(inspection.input),
          "source_sha256" => inspection.sha256,
          "source_size" => inspection.size,
          "installed_executable" => installed_path,
          "desktop_entry" => desktop_path,
          "icons" => icon_paths,
          "default_icon_name" => icon_name,
          "customizations" => {},
          "created_files" => ([installed_path, desktop_path] + icon_paths).compact,
          "created_dirs" => [app_dir],
          "installed_at" => Time.now.utc.iso8601,
          "permissions" => permission_summary(installed_path),
          "sandbox" => {
            "enabled" => false,
            "preference" => settings.fetch("sandbox_preference", "ask")
          },
          "update" => {
            "mechanism" => "manual",
            "source" => File.expand_path(inspection.input)
          },
          "warnings" => inspection.warnings + metadata.fetch("warnings", [])
        }

        manifest_path = @store.write(manifest)
        Result.ok(manifest.merge("manifest_path" => manifest_path), warnings: manifest["warnings"])
      rescue SystemCallError => e
        Result.err("Install failed: #{e.message}")
      end

      private

      def extract_metadata(installed_path, app_id)
        warnings = []
        desktop_name = nil
        icon_paths = []

        Dir.mktmpdir("depot-appimage-") do |dir|
          stdout, stderr, status = run_extract(installed_path, dir)
          unless status&.success?
            warnings << "Could not extract AppImage metadata; generated a desktop entry from the file name."
            warnings << stderr.strip unless stderr.to_s.strip.empty?
            warnings << stdout.strip unless stdout.to_s.strip.empty?
            return { "warnings" => warnings, "icons" => icon_paths }
          end

          root = File.join(dir, "squashfs-root")
          desktop = Dir.glob(File.join(root, "**", "*.desktop")).first
          desktop_metadata = parse_desktop_metadata(desktop)
          desktop_name = desktop_metadata["name"]
          icon_paths = install_icons(app_id, find_icons(root, desktop_metadata["icon"]))
        end

        { "name" => desktop_name, "icons" => icon_paths, "warnings" => warnings }.compact
      rescue Timeout::Error
        { "warnings" => ["Timed out while extracting AppImage metadata."], "icons" => [] }
      rescue SystemCallError => e
        { "warnings" => ["Could not extract AppImage metadata: #{e.message}"], "icons" => [] }
      end

      def run_extract(installed_path, dir)
        Timeout.timeout(EXTRACTION_TIMEOUT_SECONDS) do
          Open3.capture3({ "APPIMAGE_EXTRACT_AND_RUN" => "1" }, installed_path, "--appimage-extract", chdir: dir)
        end
      end

      def parse_desktop_metadata(path)
        metadata = {}
        return metadata unless path && File.exist?(path)

        File.readlines(path, chomp: true).each do |line|
          key, value = line.split("=", 2)
          next unless value

          value = value.strip
          metadata["name"] = value if key == "Name" && !value.empty?
          metadata["icon"] = value if key == "Icon" && !value.empty?
        end
        metadata
      end

      def find_icons(root, preferred_icon = nil)
        icons = [".png", ".svg", ".xpm"].flat_map do |ext|
          Dir.glob(File.join(root, "**", "*#{ext}"))
        end
        icons << File.join(root, ".DirIcon")
        preferred = preferred_icon.to_s
        preferred_base = File.basename(preferred, ".*")

        icons.select { |path| File.file?(path) && File.size(path).positive? }
             .uniq { |path| real_icon_path(path) }
             .sort_by { |path| icon_score(path, preferred_base) }
             .first(8)
      end

      def install_icons(app_id, icons)
        icons.filter_map do |source|
          ext = icon_extension(source)
          next unless [".png", ".svg", ".xpm"].include?(ext)

          size = icon_size(source)
          target_dir = File.join(Paths.icon_root, size, "apps")
          FileUtils.mkdir_p(target_dir)
          target = File.join(target_dir, "#{app_id}#{ext}")
          FileUtils.cp(source, target)
          target
        rescue SystemCallError
          nil
        end.uniq
      end

      def icon_size(path)
        parts = path.split(File::SEPARATOR)
        found = parts.find { |part| part.match?(/\A\d+x\d+\z/) }
        return found if found

        icon_extension(path) == ".svg" ? "scalable" : "256x256"
      end

      def icon_score(path, preferred_base)
        base = File.basename(path, ".*")
        ext = icon_extension(path)
        [
          preferred_base.empty? || base != preferred_base ? 1 : 0,
          File.basename(path) == ".DirIcon" ? 0 : 1,
          ext == ".svg" ? 0 : 1,
          -File.size(path)
        ]
      end

      def icon_extension(path)
        ext = File.extname(path).downcase
        return ext unless ext.empty?

        File.extname(real_icon_path(path)).downcase
      rescue SystemCallError
        ext
      end

      def real_icon_path(path)
        File.realpath(path)
      rescue SystemCallError
        path
      end

      def permission_summary(path)
        {
          "executable" => File.executable?(path),
          "requires_sudo" => false,
          "writes_outside_depot" => false,
          "notes" => ["Portable AppImage installed user-locally."]
        }
      end
    end
  end
end
