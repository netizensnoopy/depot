# frozen_string_literal: true

require_relative "manifest_store"
require_relative "paths"
require_relative "source_resolver"

module Depot
  class Doctor
    TOOLS = %w[flatpak bwrap bsdtar gtk-update-icon-cache update-desktop-database].freeze

    def initialize(store: ManifestStore.new)
      @store = store
    end

    def report
      {
        "tools" => TOOLS.to_h { |tool| [tool, command_available?(tool)] },
        "paths" => {
          "data_dir" => Dir.exist?(Paths.data_dir),
          "apps_dir" => Dir.exist?(Paths.apps_dir),
          "manifests_dir" => Dir.exist?(Paths.manifests_dir),
          "desktop_entries_dir" => Dir.exist?(Paths.desktop_entries_dir)
        },
        "manifests" => manifest_checks
      }
    end

    def healthy?
      report.fetch("manifests").all? { |manifest| manifest.fetch("ok") }
    end

    private

    def manifest_checks
      @store.all.map do |manifest|
        issues = []
        issues << "missing installed executable" if missing_path?(manifest["installed_executable"])
        issues << "missing desktop entry" if manifest["desktop_entry"].to_s != "" && !File.exist?(manifest["desktop_entry"])
        source = manifest["install_source"]
        issues << "missing original source" if source.to_s != "" && SourceResolver.resolve(source).nil?
        {
          "app_id" => manifest["app_id"],
          "name" => manifest["display_name"],
          "backend" => manifest["backend"],
          "ok" => issues.empty?,
          "issues" => issues
        }
      end
    end

    def missing_path?(path)
      path.to_s == "" || !File.exist?(path)
    end

    def command_available?(command)
      ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, command)) }
    end
  end
end
