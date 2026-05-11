# frozen_string_literal: true

require "open3"
require "time"
require_relative "installer"
require_relative "manifest_store"
require_relative "result"
require_relative "settings"
require_relative "source_resolver"
require_relative "update_downloader"
require_relative "uninstaller"

module Depot
  class Updater
    def self.update(app_id, options = {})
      new.update(app_id, options)
    end

    def self.update_all(options = {})
      new.update_all(options)
    end

    def self.set_source(app_id, url)
      new.set_source(app_id, url)
    end

    def initialize(store: ManifestStore.new, settings: Settings.new)
      @store = store
      @settings = settings
    end

    def records
      @store.all.map { |manifest| update_record(manifest) }
    end

    def update(app_id, options = {})
      return Result.err("Updates are disabled in Depot settings.") unless updates_enabled?(options)

      manifest = @store.find(app_id)
      return Result.err("No installed app found for #{app_id}") unless manifest

      case manifest.fetch("backend", "")
      when "flatpak"
        update_flatpak(manifest)
      else
        reinstall_from_source(manifest, options)
      end
    end

    def update_all(options = {})
      return Result.err("Updates are disabled in Depot settings.") unless updates_enabled?(options)

      results = records.map do |record|
        next { "app_id" => record.fetch("app_id"), "ok" => false, "error" => record.fetch("status") } unless record.fetch("enabled")

        result = update(record.fetch("app_id"), options)
        { "app_id" => record.fetch("app_id"), "ok" => result.ok?, "error" => result.error, "value" => result.value }
      end
      failed = results.reject { |result| result.fetch("ok") }
      return Result.err("#{failed.length} updates failed.", warnings: failed.map { |result| "#{result.fetch("app_id")}: #{result.fetch("error")}" }) unless failed.empty?

      Result.ok({ "updated" => results })
    end

    def set_source(app_id, url)
      manifest = @store.find(app_id)
      return Result.err("No installed app found for #{app_id}") unless manifest

      return Result.err("Update URL must use https://.") unless UpdateDownloader.https_url?(url)

      update = manifest.fetch("update", {}).merge(
        "source" => url,
        "mechanism" => "url-download",
        "status" => "ready",
        "last_checked_at" => Time.now.utc.iso8601
      )
      @store.write(manifest.merge("update" => update))
      Result.ok(@store.find(app_id))
    end

    private

    def updates_enabled?(options)
      return true if options[:force]

      @settings.load.fetch("updates_enabled", true)
    end

    def update_record(manifest)
      source = SourceResolver.resolve(manifest["install_source"])
      update_url = update_url(manifest)
      method = update_method(manifest)
      enabled = method == "flatpak" || !source.nil? || !update_url.nil?
      status = update_status(method, source, update_url, manifest)
      {
        "app_id" => manifest.fetch("app_id"),
        "display_name" => manifest.fetch("display_name"),
        "backend" => manifest.fetch("backend"),
        "method" => method,
        "enabled" => enabled,
        "status" => status,
        "last_updated_at" => manifest.dig("update", "last_updated_at")
      }
    end

    def update_method(manifest)
      return "flatpak" if manifest.fetch("backend") == "flatpak"
      return "url-download" if update_url(manifest)

      "reinstall-source"
    end

    def update_status(method, source, update_url, manifest)
      return "Ready" if method == "flatpak"
      return "Ready from URL" if update_url
      return "Ready" if source

      raw_source = manifest.dig("update", "source") || manifest["install_source"]
      if SourceResolver.url?(raw_source)
        "Only https update URLs are supported"
      else
        "Original installer is missing"
      end
    end

    def update_url(manifest)
      source = manifest.dig("update", "source")
      source = manifest["install_source"] if source.to_s.empty?
      return nil unless SourceResolver.https_url?(source)

      source
    end

    def update_flatpak(manifest)
      flatpak_id = manifest.dig("flatpak", "app_id") || manifest.dig("package", "Name")
      return Result.err("Flatpak manifest is missing the Flatpak app ID.") if flatpak_id.to_s.empty?
      return Result.err("Flatpak is not installed on this system.") unless command_available?("flatpak")

      stdout, stderr, status = Open3.capture3("flatpak", "update", "--user", "--noninteractive", "-y", flatpak_id)
      return Result.err("Flatpak update failed: #{command_message(stdout, stderr)}") unless status.success?

      update_manifest(manifest, "flatpak", "updated")
      Result.ok(@store.find(manifest.fetch("app_id")), warnings: [command_message(stdout, stderr)].reject(&:empty?))
    end

    def reinstall_from_source(manifest, options)
      url = update_url(manifest)
      return reinstall_from_url(manifest, url, options) if url

      source = SourceResolver.resolve(manifest["install_source"])
      return Result.err("Original installer is missing: #{manifest["install_source"]}") unless source

      uninstall = Uninstaller.new(store: @store).uninstall(manifest.fetch("app_id"))
      return uninstall unless uninstall.ok?

      install = Installer.new(store: @store, settings: @settings).install(source, settings: @settings.load.merge(options.fetch(:settings, {})))
      return install unless install.ok?

      updated = install.value
      update_manifest(updated, "reinstall-source", "updated")
      Result.ok(@store.find(updated.fetch("app_id")), warnings: install.warnings)
    end

    def reinstall_from_url(manifest, url, options)
      UpdateDownloader.download(url) do |path, metadata|
        inspection = Inspector.inspect(path)
        return inspection unless inspection.ok?

        compatible = compatible_update?(manifest, inspection.value)
        return Result.err(compatible) unless compatible == true

        uninstall = Uninstaller.new(store: @store).uninstall(manifest.fetch("app_id"))
        return uninstall unless uninstall.ok?

        install = Installer.new(store: @store, settings: @settings).install(path, settings: @settings.load.merge(options.fetch(:settings, {})))
        return install unless install.ok?

        updated = install.value
        stored = @store.find(updated.fetch("app_id")) || updated
        @store.write(stored.merge("install_source" => url))
        update_manifest(
          @store.find(updated.fetch("app_id")) || stored,
          "url-download",
          "updated",
          "source" => url,
          "last_download_sha256" => metadata.fetch("sha256"),
          "last_download_size" => metadata.fetch("size")
        )
        Result.ok(@store.find(updated.fetch("app_id")), warnings: install.warnings)
      end
    end

    def compatible_update?(manifest, inspection)
      expected = expected_formats(manifest.fetch("backend", ""))
      return true if expected.include?(inspection.format)

      "Downloaded update is #{inspection.format}, but #{manifest.fetch("display_name")} was installed as #{manifest.fetch("backend")}. Depot will not switch package families during an update."
    end

    def expected_formats(backend)
      case backend
      when "appimage" then ["appimage"]
      when "deb-portable" then ["deb"]
      when "rpm-portable" then ["rpm"]
      when "archive-portable" then %w[tar.gz tar.xz tar.zst]
      when "flatpak" then ["flatpakref"]
      else [backend]
      end
    end

    def update_manifest(manifest, method, status, extra = {})
      stored = @store.find(manifest.fetch("app_id")) || manifest
      update = stored.fetch("update", {}).merge(
        "mechanism" => method,
        "status" => status,
        "last_checked_at" => Time.now.utc.iso8601,
        "last_updated_at" => Time.now.utc.iso8601
      ).merge(extra)
      @store.write(stored.merge("update" => update))
    end

    def command_message(stdout, stderr)
      [stderr, stdout].map(&:to_s).find { |text| text.strip != "" }.to_s.strip
    end

    def command_available?(command)
      ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, command)) }
    end
  end
end
