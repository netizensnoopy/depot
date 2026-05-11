# frozen_string_literal: true

require "json"
require "optparse"
require_relative "../depot"

module Depot
  class CLI
    def initialize(stdout: $stdout, stderr: $stderr)
      @stdout = stdout
      @stderr = stderr
    end

    def run(argv)
      command = argv.shift
      case command
      when "inspect"
        inspect_command(argv)
      when "install"
        install_command(argv)
      when "list"
        list_command(argv)
      when "info"
        info_command(argv)
      when "uninstall", "remove"
        uninstall_command(argv)
      when "update"
        update_command(argv)
      when "update-source"
        update_source_command(argv)
      when "sandbox"
        sandbox_command(argv)
      when "doctor"
        doctor_command(argv)
      when "settings"
        settings_command(argv)
      when "-h", "--help", nil
        help
        0
      when "-v", "--version"
        @stdout.puts "Depot #{Depot::VERSION}"
        0
      else
        @stderr.puts "Unknown command: #{command}"
        help(@stderr)
        1
      end
    end

    private

    def inspect_command(argv)
      json = argv.delete("--json")
      input = argv.shift
      return usage_error("Usage: depot inspect [--json] PATH_OR_URL") unless input

      result = Inspector.inspect(input)
      return print_error(result) unless result.ok?

      if json
        @stdout.puts JSON.pretty_generate(result.value.to_h)
      else
        inspection = result.value
        @stdout.puts "Input: #{inspection.input}"
        @stdout.puts "Format: #{inspection.format} (#{inspection.confidence})"
        @stdout.puts "Name: #{inspection.display_name}"
        @stdout.puts "Size: #{inspection.size || "unknown"}"
        @stdout.puts "SHA-256: #{inspection.sha256 || "unknown"}"
        @stdout.puts "Executable: #{inspection.executable ? "yes" : "no"}"
        print_deb_metadata(inspection) if inspection.deb?
        print_archive_metadata(inspection) if inspection.archive?
        print_rpm_metadata(inspection) if inspection.rpm?
        print_flatpakref_metadata(inspection) if inspection.flatpakref?
        print_list("Warnings", inspection.warnings)
        print_list("Risks", inspection.risks)
      end
      0
    end

    def install_command(argv)
      json = argv.delete("--json")
      no_desktop = argv.delete("--no-desktop")
      input = argv.shift
      return usage_error("Usage: depot install [--json] [--no-desktop] PATH") unless input

      settings = {}
      settings["desktop_integration"] = false if no_desktop
      result = Installer.install(input, settings:)
      return print_error(result) unless result.ok?

      manifest = result.value
      if json
        @stdout.puts JSON.pretty_generate(manifest)
      else
        @stdout.puts "Installed #{manifest.fetch("display_name")} as #{manifest.fetch("app_id")}"
        @stdout.puts "Executable: #{manifest.fetch("installed_executable")}"
        @stdout.puts "Desktop entry: #{manifest["desktop_entry"] || "disabled"}"
        @stdout.puts "Manifest: #{manifest.fetch("manifest_path")}"
        print_list("Warnings", result.warnings)
      end
      0
    end

    def list_command(_argv)
      apps = ManifestStore.new.all
      if apps.empty?
        @stdout.puts "No Depot apps installed."
      else
        apps.each do |manifest|
          @stdout.puts "#{manifest.fetch("app_id")}\t#{manifest.fetch("display_name")}\t#{manifest.fetch("backend")}"
        end
      end
      0
    end

    def info_command(argv)
      json = argv.delete("--json")
      app_id = argv.shift
      return usage_error("Usage: depot info [--json] APP_ID") unless app_id

      manifest = ManifestStore.new.find(app_id)
      return usage_error("No installed app found for #{app_id}") unless manifest

      if json
        @stdout.puts JSON.pretty_generate(manifest)
      else
        @stdout.puts "App: #{manifest.fetch("display_name")} (#{manifest.fetch("app_id")})"
        @stdout.puts "Backend: #{manifest.fetch("backend")}"
        @stdout.puts "Source: #{manifest.fetch("install_source")}"
        @stdout.puts "Update source: #{manifest.dig("update", "source") || "none"}"
        @stdout.puts "Sandbox: #{Sandbox.summary(manifest)}"
        @stdout.puts "Executable: #{manifest.fetch("installed_executable")}"
        @stdout.puts "Desktop entry: #{manifest["desktop_entry"] || "none"}"
        @stdout.puts "Installed: #{manifest.fetch("installed_at")}"
        print_list("Created files", manifest.fetch("created_files", []))
        print_list("Warnings", manifest.fetch("warnings", []))
      end
      0
    end

    def uninstall_command(argv)
      app_id = argv.shift
      return usage_error("Usage: depot uninstall APP_ID") unless app_id

      result = Uninstaller.uninstall(app_id)
      return print_error(result) unless result.ok?

      @stdout.puts "Uninstalled #{app_id}"
      print_list("Deleted files", result.value.fetch("deleted_files", []))
      0
    end

    def update_command(argv)
      json = argv.delete("--json")
      all = argv.delete("--all")
      app_id = argv.shift
      return usage_error("Usage: depot update [--json] APP_ID | --all") unless all || app_id

      result = all ? Updater.update_all : Updater.update(app_id)
      return print_error(result) unless result.ok?

      if json
        @stdout.puts JSON.pretty_generate(result.value)
      elsif all
        @stdout.puts "Updated all available apps."
      else
        manifest = result.value
        @stdout.puts "Updated #{manifest.fetch("display_name")} (#{manifest.fetch("app_id")})"
      end
      0
    end

    def update_source_command(argv)
      app_id = argv.shift
      url = argv.shift
      return usage_error("Usage: depot update-source APP_ID HTTPS_URL") unless app_id && url

      result = Updater.set_source(app_id, url)
      return print_error(result) unless result.ok?

      @stdout.puts "Set update source for #{app_id}."
      0
    end

    def sandbox_command(argv)
      app_id = argv.shift
      mode = argv.shift
      return usage_error("Usage: depot sandbox APP_ID [inherit|enabled|disabled]") unless app_id

      manifest = ManifestStore.new.find(app_id)
      return usage_error("No installed app found for #{app_id}") unless manifest

      if mode.nil?
        @stdout.puts Sandbox.summary(manifest)
        return 0
      end

      result = Sandbox.set(app_id, { "mode" => mode })
      return print_error(result) unless result.ok?

      @stdout.puts "Set sandbox for #{app_id} to #{result.value.fetch("sandbox").fetch("mode")}."
      0
    end

    def settings_command(argv)
      settings = Settings.new
      values = settings.load
      if argv.empty?
        @stdout.puts JSON.pretty_generate(values)
        return 0
      end

      if argv.first == "set"
        key = argv[1]
        value = argv[2]
        return usage_error("Usage: depot settings set KEY VALUE") unless key && value

        parsed = case value
                 when "true" then true
                 when "false" then false
                 else value
                 end
        saved = settings.save(values.merge(key => parsed))
        @stdout.puts JSON.pretty_generate(saved)
        return 0
      end

      usage_error("Usage: depot settings [set KEY VALUE]")
    end

    def doctor_command(argv)
      json = argv.delete("--json")
      report = Doctor.new.report
      if json
        @stdout.puts JSON.pretty_generate(report)
        return 0
      end

      @stdout.puts "Depot doctor"
      @stdout.puts "Tools:"
      report.fetch("tools").each do |tool, present|
        @stdout.puts "  - #{tool}: #{present ? "found" : "missing"}"
      end
      @stdout.puts "Paths:"
      report.fetch("paths").each do |path, present|
        @stdout.puts "  - #{path}: #{present ? "ok" : "missing"}"
      end
      manifests = report.fetch("manifests")
      if manifests.empty?
        @stdout.puts "Manifests: none installed"
      else
        @stdout.puts "Manifests:"
        manifests.each do |manifest|
          status = manifest.fetch("ok") ? "ok" : manifest.fetch("issues").join(", ")
          @stdout.puts "  - #{manifest.fetch("app_id")}: #{status}"
        end
      end
      0
    end

    def print_error(result)
      @stderr.puts result.error
      print_list("Warnings", result.warnings, io: @stderr)
      1
    end

    def usage_error(message)
      @stderr.puts message
      1
    end

    def print_list(title, items, io: @stdout)
      return if items.nil? || items.empty?

      io.puts "#{title}:"
      items.each { |item| io.puts "  - #{item}" }
    end

    def print_deb_metadata(inspection)
      metadata = inspection.metadata
      @stdout.puts "Package: #{metadata["package"] || "unknown"}"
      @stdout.puts "Version: #{metadata["version"] || "unknown"}"
      @stdout.puts "Architecture: #{metadata["architecture"] || "unknown"}"
      @stdout.puts "Debian control archive: #{metadata["control_archive"] || "unknown"}"
      @stdout.puts "Debian data archive: #{metadata["data_archive"] || "unknown"}"
      print_list("Maintainer scripts", metadata.fetch("maintainer_scripts", []))
      print_list("Desktop entries", metadata.fetch("desktop_entries", []))
      print_list("Executable candidates", metadata.fetch("executable_candidates", []))
    end

    def print_archive_metadata(inspection)
      metadata = inspection.metadata
      @stdout.puts "Archive format: #{metadata["archive_format"] || inspection.format}"
      @stdout.puts "Archive root: #{metadata["archive_root"] || "mixed"}"
      print_list("Desktop entries", metadata.fetch("desktop_entries", []))
      print_list("Executable candidates", metadata.fetch("executable_candidates", []))
      print_list("Installer-like scripts", metadata.fetch("script_entries", []))
      print_list("Source/build markers", metadata.fetch("source_markers", []))
    end

    def print_rpm_metadata(inspection)
      metadata = inspection.metadata
      version = [metadata["version"], metadata["release"]].compact.join("-")
      @stdout.puts "Package: #{metadata["package"] || "unknown"}"
      @stdout.puts "Version: #{version.empty? ? "unknown" : version}"
      @stdout.puts "Architecture: #{metadata["architecture"] || "unknown"}"
      @stdout.puts "RPM payload: #{metadata["payload_format"] || "unknown"} / #{metadata["payload_compressor"] || "unknown"}"
      print_list("RPM requirements", metadata.fetch("requires", []))
      print_list("RPM scriptlets", metadata.fetch("scriptlets", []))
      print_list("Desktop entries", metadata.fetch("desktop_entries", []))
      print_list("Executable candidates", metadata.fetch("executable_candidates", []))
    end

    def print_flatpakref_metadata(inspection)
      metadata = inspection.metadata
      @stdout.puts "Flatpak ID: #{metadata["name"] || "unknown"}"
      @stdout.puts "Title: #{metadata["title"] || inspection.display_name}"
      @stdout.puts "Branch: #{metadata["branch"] || "master"}"
      @stdout.puts "Remote URL: #{metadata["url"] || "unknown"}"
      @stdout.puts "Suggested remote: #{metadata["suggest_remote_name"] || "none"}"
      @stdout.puts "Runtime ref: #{metadata["is_runtime"] ? "yes" : "no"}"
      @stdout.puts "Embedded GPG key: #{metadata["gpg_key_present"] ? "yes" : "no"}"
    end

    def help(io = @stdout)
      io.puts <<~HELP
        Depot #{Depot::VERSION}

        Usage:
          depot inspect [--json] PATH_OR_URL
          depot install [--json] [--no-desktop] PATH
          depot list
          depot info [--json] APP_ID
          depot uninstall APP_ID
          depot update [--json] APP_ID
          depot update [--json] --all
          depot update-source APP_ID HTTPS_URL
          depot sandbox APP_ID [inherit|enabled|disabled]
          depot doctor [--json]
          depot settings [set KEY VALUE]
      HELP
    end
  end
end
