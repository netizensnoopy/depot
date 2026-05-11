# frozen_string_literal: true

require "fileutils"
require "open3"
require_relative "manifest_store"
require_relative "result"

module Depot
  class Uninstaller
    def self.uninstall(app_id)
      new.uninstall(app_id)
    end

    def initialize(store: ManifestStore.new)
      @store = store
    end

    def uninstall(app_id)
      manifest = @store.find(app_id)
      return Result.err("No installed app found for #{app_id}") unless manifest

      flatpak = uninstall_flatpak(manifest)
      return flatpak unless flatpak.ok?

      deleted = []
      manifest.fetch("created_files", []).each do |path|
        next unless safe_delete_file?(path)

        FileUtils.rm_f(path)
        deleted << path
      end

      manifest.fetch("created_dirs", []).reverse_each do |path|
        next unless safe_delete_dir?(path)

        FileUtils.rm_rf(path) if Dir.exist?(path)
      rescue SystemCallError
        nil
      end

      @store.delete(app_id)
      Result.ok({ "app_id" => app_id, "deleted_files" => deleted })
    rescue SystemCallError => e
      Result.err("Uninstall failed: #{e.message}")
    end

    private

    def uninstall_flatpak(manifest)
      return Result.ok unless manifest["backend"] == "flatpak"

      flatpak_id = manifest.dig("flatpak", "app_id") || manifest.dig("package", "Name")
      return Result.err("Flatpak manifest is missing the Flatpak app ID.") if flatpak_id.to_s.empty?
      return Result.err("Flatpak is not installed on this system.") unless command_available?("flatpak")

      stdout, stderr, status = Open3.capture3("flatpak", "uninstall", "--user", "--noninteractive", "-y", flatpak_id)
      return Result.ok if status.success?

      message = [stderr, stdout].map(&:to_s).find { |text| text.strip != "" } || "flatpak uninstall failed"
      Result.err("Flatpak uninstall failed: #{message.strip}")
    end

    def safe_delete_file?(path)
      return false unless path.is_a?(String) && !path.empty?
      return false unless File.file?(path) || File.symlink?(path)

      expanded = File.expand_path(path)
      allowed_roots.any? { |root| expanded.start_with?(root + File::SEPARATOR) }
    end

    def safe_delete_dir?(path)
      return false unless path.is_a?(String) && !path.empty?

      expanded = File.expand_path(path)
      expanded.start_with?(File.expand_path(Depot::Paths.apps_dir) + File::SEPARATOR)
    end

    def allowed_roots
      @allowed_roots ||= [
        Depot::Paths.data_dir,
        Depot::Paths.desktop_entries_dir,
        Depot::Paths.icon_root
      ].map { |path| File.expand_path(path) }
    end

    def command_available?(command)
      ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, command)) }
    end
  end
end
