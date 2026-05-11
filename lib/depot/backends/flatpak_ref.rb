# frozen_string_literal: true

require "fileutils"
require "open3"
require "time"
require_relative "../packages/flatpak_ref"
require_relative "../paths"
require_relative "../result"
require_relative "../util"
require_relative "support"

module Depot
  module Backends
    class FlatpakRefBackend
      include Support

      def initialize(store:)
        @store = store
      end

      def install(inspection, settings: {})
        return Result.err("Flatpak backend cannot install #{inspection.format}") unless inspection.flatpakref?
        return Result.err("Flatpak is not installed on this system.") unless command_available?("flatpak")

        Paths.ensure_base_dirs
        ref = FlatpakRef.new(inspection.input)
        return Result.err("Invalid Flatpak reference.") unless ref.valid?
        return Result.err("Depot only installs Flatpak application refs right now.") if ref.runtime?

        app_id = Util.unique_id(Util.slug(ref.name), @store.ids)
        app_dir = File.join(Paths.apps_dir, app_id)
        FileUtils.mkdir_p(app_dir)

        stdout, stderr, status = Open3.capture3(
          "flatpak", "install", "--user", "--noninteractive", "-y", "--or-update", "--from", inspection.input
        )
        unless status.success?
          message = [stderr, stdout].map(&:to_s).find { |text| text.strip != "" } || "flatpak install failed"
          return Result.err("Flatpak install failed: #{message.strip}")
        end

        launcher = write_launcher(app_dir, ref.name)
        desktop_entry = exported_desktop_entry(ref.name)
        display_name = desktop_entry ? desktop_name(File.read(desktop_entry)) : ref.display_name
        warnings = inspection.warnings + ["Flatpak handled the download, verification, sandbox, desktop integration, and runtime dependencies."]
        manifest = {
          "schema_version" => 1,
          "app_id" => app_id,
          "display_name" => display_name,
          "default_display_name" => display_name,
          "backend" => "flatpak",
          "install_source" => File.expand_path(inspection.input),
          "source_sha256" => inspection.sha256,
          "source_size" => inspection.size,
          "installed_executable" => launcher,
          "desktop_entry" => desktop_entry,
          "icons" => [],
          "created_files" => [launcher],
          "created_dirs" => [app_dir],
          "installed_at" => Time.now.utc.iso8601,
          "package" => ref.fields,
          "flatpak" => {
            "app_id" => ref.name,
            "branch" => ref.branch,
            "remote" => ref.remote_name,
            "origin" => flatpak_info(ref.name, "--show-origin"),
            "ref" => flatpak_info(ref.name, "--show-ref")
          },
          "permissions" => {
            "executable" => true,
            "requires_sudo" => false,
            "writes_outside_depot" => false,
            "notes" => ["Flatpak manages this app, its sandbox, remotes, runtimes, and exported desktop integration."]
          },
          "sandbox" => {
            "enabled" => true,
            "manager" => "flatpak",
            "preference" => settings.fetch("sandbox_preference", "ask")
          },
          "update" => {
            "mechanism" => "flatpak",
            "source" => ref.url
          },
          "warnings" => warnings
        }

        manifest_path = @store.write(manifest)
        Result.ok(manifest.merge("manifest_path" => manifest_path), warnings:)
      rescue FlatpakRef::FormatError, SystemCallError => e
        Result.err("Flatpak install failed: #{e.message}")
      end

      private

      def write_launcher(app_dir, flatpak_id)
        launcher = File.join(app_dir, "run")
        write_shell_launcher(launcher, "flatpak", "run", "--user", flatpak_id)
      end

      def exported_desktop_entry(flatpak_id)
        candidates = [
          File.join(Paths.data_home, "flatpak", "exports", "share", "applications", "#{flatpak_id}.desktop"),
          File.join("/var", "lib", "flatpak", "exports", "share", "applications", "#{flatpak_id}.desktop")
        ]
        candidates.find { |path| File.file?(path) }
      end

      def desktop_name(contents)
        desktop_name_from(contents) || "Flatpak App"
      rescue SystemCallError
        "Flatpak App"
      end

      def flatpak_info(flatpak_id, flag)
        stdout, = Open3.capture2("flatpak", "info", "--user", flag, flatpak_id)
        stdout.strip.empty? ? nil : stdout.strip
      rescue SystemCallError
        nil
      end

    end
  end
end
