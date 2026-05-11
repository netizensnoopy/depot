# frozen_string_literal: true

require "fileutils"
require "time"
require_relative "desktop_entry"
require_relative "manifest_store"
require_relative "paths"
require_relative "result"
require_relative "sandbox"

module Depot
  class AppCustomizer
    ICON_EXTENSIONS = [".png", ".svg", ".xpm"].freeze

    def initialize(store: ManifestStore.new)
      @store = store
    end

    def rename(app_id, title)
      manifest = @store.find(app_id)
      return Result.err("No Depot manifest found for #{app_id}.") unless manifest

      title = title.to_s.strip
      return Result.err("Title cannot be empty.") if title.empty?

      ensure_defaults(manifest)
      manifest["display_name"] = title
      manifest["customizations"]["display_name"] = title
      persist(manifest)
    end

    def change_icon(app_id, source_path)
      manifest = @store.find(app_id)
      return Result.err("No Depot manifest found for #{app_id}.") unless manifest

      source_path = File.expand_path(source_path.to_s)
      return Result.err("Icon file does not exist.") unless File.file?(source_path)

      ext = File.extname(source_path).downcase
      return Result.err("Choose a PNG, SVG, or XPM icon.") unless ICON_EXTENSIONS.include?(ext)

      ensure_defaults(manifest)
      remove_custom_icon(manifest)

      icon_name = "#{manifest.fetch("app_id")}-custom"
      target_dir = File.join(Paths.icon_root, icon_theme_size(source_path, ext), "apps")
      FileUtils.mkdir_p(target_dir)
      target = File.join(target_dir, "#{icon_name}#{ext}")
      FileUtils.cp(source_path, target)

      manifest["custom_icon"] = {
        "source" => source_path,
        "path" => target,
        "icon_name" => icon_name,
        "set_at" => Time.now.utc.iso8601
      }
      manifest["created_files"] = (manifest["created_files"].to_a + [target]).uniq
      persist(manifest)
    rescue SystemCallError => e
      Result.err("Could not change icon: #{e.message}")
    end

    def reset(app_id)
      manifest = @store.find(app_id)
      return Result.err("No Depot manifest found for #{app_id}.") unless manifest

      ensure_defaults(manifest)
      remove_custom_icon(manifest)
      manifest["display_name"] = manifest.fetch("default_display_name")
      manifest.delete("custom_icon")
      manifest["customizations"] = {}
      persist(manifest)
    end

    private

    def ensure_defaults(manifest)
      manifest["default_display_name"] ||= manifest.fetch("display_name")
      manifest["default_icon_name"] = default_icon_name(manifest) unless manifest.key?("default_icon_name")
      manifest["customizations"] ||= {}
    end

    def default_icon_name(manifest)
      manifest["icons"].to_a.any? ? manifest.fetch("app_id") : nil
    end

    def persist(manifest)
      rewrite_desktop_entry(manifest)
      path = @store.write(manifest)
      Result.ok(manifest.merge("manifest_path" => path))
    rescue SystemCallError => e
      Result.err("Could not update app integration: #{e.message}")
    end

    def rewrite_desktop_entry(manifest)
      desktop_path = manifest["desktop_entry"]
      return unless desktop_path && !desktop_path.empty?

      FileUtils.mkdir_p(File.dirname(desktop_path))
      entry = DesktopEntry.new(
        app_id: manifest.fetch("app_id"),
        name: manifest.fetch("display_name"),
        exec_path: Sandbox.launch_path(manifest),
        icon_name: active_icon_name(manifest)
      )
      File.write(desktop_path, entry.contents)
      manifest["created_files"] = (manifest["created_files"].to_a + [desktop_path]).uniq
    end

    def active_icon_name(manifest)
      custom = manifest["custom_icon"]
      return custom["path"] if custom && custom["path"].to_s != ""

      manifest["default_icon_name"]
    end

    def icon_theme_size(path, ext)
      return "scalable" if ext == ".svg"
      return png_size(path) if ext == ".png"

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

    def remove_custom_icon(manifest)
      custom = manifest["custom_icon"]
      return unless custom

      path = custom["path"]
      FileUtils.rm_f(path) if path && custom_icon_path?(path)
      manifest["created_files"] = manifest["created_files"].to_a - [path]
    end

    def custom_icon_path?(path)
      expanded = File.expand_path(path)
      expanded.start_with?(File.expand_path(Paths.icon_root) + File::SEPARATOR)
    end
  end
end
