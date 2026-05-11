# frozen_string_literal: true

require "time"
require_relative "backends/app_image"
require_relative "backends/archive"
require_relative "backends/deb"
require_relative "backends/flatpak_ref"
require_relative "backends/rpm"
require_relative "inspector"
require_relative "manifest_store"
require_relative "result"
require_relative "sandbox"
require_relative "settings"

module Depot
  class Installer
    def self.install(input, options = {})
      new.install(input, options)
    end

    def initialize(store: ManifestStore.new, settings: Settings.new)
      @store = store
      @settings = settings
    end

    def install(input, options = {})
      inspection_result = Inspector.inspect(input)
      return inspection_result unless inspection_result.ok?

      inspection = inspection_result.value
      merged_settings = @settings.load.merge(options.fetch(:settings, {}))
      result = case inspection.format
               when "appimage"
                 Backends::AppImage.new(store: @store).install(inspection, settings: merged_settings)
               when "deb"
                 Backends::Deb.new(store: @store).install(inspection, settings: merged_settings)
               when "tar.gz", "tar.xz", "tar.zst"
                 Backends::Archive.new(store: @store).install(inspection, settings: merged_settings)
               when "rpm"
                 Backends::Rpm.new(store: @store).install(inspection, settings: merged_settings)
               when "flatpakref"
                 Backends::FlatpakRefBackend.new(store: @store).install(inspection, settings: merged_settings)
               else
                 Result.err("No installer backend is available for detected format: #{inspection.format}")
               end
      return result unless result.ok?

      sandboxed = Sandbox.apply(result.value, settings: merged_settings, store: @store)
      return sandboxed unless sandboxed.ok?

      Result.ok(sandboxed.value, warnings: result.warnings)
    end
  end
end
