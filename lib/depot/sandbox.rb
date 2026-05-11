# frozen_string_literal: true

require "fileutils"
require "shellwords"
require "time"
require_relative "desktop_entry"
require_relative "manifest_store"
require_relative "paths"
require_relative "result"
require_relative "settings"

module Depot
  module Sandbox
    PORTABLE_BACKENDS = %w[appimage deb-portable rpm-portable archive-portable].freeze
    MODES = %w[inherit enabled disabled].freeze
    PROFILES = %w[relaxed balanced strict].freeze
    HOME_ACCESS = %w[isolated documents full].freeze

    module_function

    def apply(manifest, settings: Settings.new.load, store: ManifestStore.new)
      normalized = normalize(manifest, settings)
      normalized = write_or_remove_launcher(normalized, settings)
      rewrite_desktop_entry(normalized) if portable?(normalized)
      path = store.write(normalized)
      Result.ok(normalized.merge("manifest_path" => path))
    rescue SystemCallError => e
      Result.err("Could not update sandbox settings: #{e.message}")
    end

    def set(app_id, values = {}, store: ManifestStore.new, settings: Settings.new.load)
      manifest = store.find(app_id)
      return Result.err("No installed app found for #{app_id}.") unless manifest

      sandbox = normalize(manifest, settings).fetch("sandbox", {})
      mode = values["mode"] || values[:mode]
      profile = values["profile"] || values[:profile]
      home_access = values["home_access"] || values[:home_access]
      return Result.err("Sandbox mode must be one of: #{MODES.join(", ")}.") if mode && !MODES.include?(mode.to_s)
      return Result.err("Sandbox profile must be one of: #{PROFILES.join(", ")}.") if profile && !PROFILES.include?(profile.to_s)
      return Result.err("Sandbox home access must be one of: #{HOME_ACCESS.join(", ")}.") if home_access && !HOME_ACCESS.include?(home_access.to_s)

      sandbox["mode"] = normalize_choice(mode, MODES, sandbox.fetch("mode", "inherit"))
      sandbox["profile"] = normalize_choice(profile, PROFILES, sandbox.fetch("profile", "balanced"))
      sandbox["home_access"] = normalize_choice(home_access, HOME_ACCESS, sandbox.fetch("home_access", "documents"))
      sandbox["network"] = bool_value(values.key?("network") ? values["network"] : values[:network], sandbox.fetch("network", true))
      sandbox["updated_at"] = Time.now.utc.iso8601
      apply(manifest.merge("sandbox" => sandbox), settings:, store:)
    end

    def launch_path(manifest, settings: Settings.new.load)
      normalized = normalize(manifest, settings)
      sandbox = normalized.fetch("sandbox", {})
      launcher = sandbox["launcher"]
      return launcher if effective_enabled?(normalized, settings) && launcher.to_s != "" && File.executable?(launcher)

      normalized["installed_executable"]
    end

    def summary(manifest, settings: Settings.new.load)
      normalized = normalize(manifest, settings)
      sandbox = normalized.fetch("sandbox", {})
      if normalized["backend"] == "flatpak"
        return "Flatpak managed"
      end
      unless portable?(normalized)
        return "Unsupported for this backend"
      end

      mode = sandbox.fetch("mode", "inherit")
      state = effective_enabled?(normalized, settings) ? "enabled" : "disabled"
      manager = command_available?("bwrap") ? "Bubblewrap" : "Bubblewrap missing"
      "#{state} (#{mode}, #{sandbox.fetch("profile", "balanced")}, #{sandbox.fetch("home_access", "documents")} home, #{sandbox.fetch("network", true) ? "network" : "no network"}, #{manager})"
    end

    def normalize(manifest, settings = Settings.new.load)
      sandbox = manifest.fetch("sandbox", {}).dup
      backend = manifest["backend"]
      if backend == "flatpak"
        sandbox["manager"] = "flatpak"
        sandbox["mode"] ||= "enabled"
        sandbox["enabled"] = true
        return manifest.merge("sandbox" => sandbox)
      end

      sandbox["manager"] = "bubblewrap" if portable?(manifest)
      sandbox["mode"] ||= legacy_mode(sandbox)
      sandbox["profile"] = normalize_choice(sandbox["profile"], PROFILES, settings.fetch("sandbox_profile", "balanced"))
      sandbox["home_access"] = normalize_choice(sandbox["home_access"], HOME_ACCESS, settings.fetch("sandbox_home_access", "documents"))
      sandbox["network"] = bool_value(sandbox.fetch("network", settings.fetch("sandbox_network", true)), true)
      sandbox["enabled"] = effective_enabled?(manifest.merge("sandbox" => sandbox), settings)
      manifest.merge("sandbox" => sandbox)
    end

    def effective_enabled?(manifest, settings = Settings.new.load)
      return true if manifest["backend"] == "flatpak"
      return false unless portable?(manifest)

      mode = manifest.fetch("sandbox", {}).fetch("mode", "inherit")
      return true if mode == "enabled"
      return false if mode == "disabled"

      %w[prefer-on on enabled].include?(settings.fetch("sandbox_preference", "ask"))
    end

    def portable?(manifest)
      PORTABLE_BACKENDS.include?(manifest["backend"])
    end

    def command_available?(command)
      ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, command)) }
    end

    def normalize_choice(value, allowed, fallback)
      value = value.to_s
      allowed.include?(value) ? value : fallback
    end

    def bool_value(value, fallback)
      return value if value == true || value == false
      return true if value.to_s == "true"
      return false if value.to_s == "false"

      fallback
    end

    def legacy_mode(sandbox)
      return "enabled" if sandbox["enabled"] == true

      "inherit"
    end

    def write_or_remove_launcher(manifest, settings)
      sandbox = manifest.fetch("sandbox", {})
      launcher = sandbox["launcher"]
      if !effective_enabled?(manifest, settings) || !portable?(manifest)
        FileUtils.rm_f(launcher) if safe_launcher_path?(manifest, launcher)
        sandbox.delete("launcher")
        sandbox["enabled"] = false
        return manifest.merge("sandbox" => sandbox)
      end

      app_dir = app_dir_for(manifest)
      return manifest unless app_dir

      FileUtils.mkdir_p(app_dir)
      FileUtils.mkdir_p(File.join(app_dir, "sandbox-home"))
      launcher = File.join(app_dir, "depot-sandbox-launch")
      File.write(launcher, launcher_script(manifest, app_dir))
      File.chmod(0o755, launcher)
      manifest["created_files"] = (manifest["created_files"].to_a + [launcher]).uniq
      sandbox["launcher"] = launcher
      sandbox["enabled"] = true
      manifest.merge("sandbox" => sandbox)
    end

    def app_dir_for(manifest)
      manifest.fetch("created_dirs", []).find { |path| path.to_s.start_with?(Paths.apps_dir) } ||
        safe_parent_app_dir(manifest["installed_executable"])
    end

    def safe_parent_app_dir(path)
      expanded = File.expand_path(path.to_s)
      root = File.expand_path(Paths.apps_dir)
      return nil unless expanded.start_with?(root + File::SEPARATOR)

      parts = expanded.delete_prefix(root + File::SEPARATOR).split(File::SEPARATOR)
      return nil if parts.empty?

      File.join(root, parts.first)
    end

    def safe_launcher_path?(manifest, path)
      return false if path.to_s.empty?

      app_dir = app_dir_for(manifest)
      return false unless app_dir

      File.expand_path(path).start_with?(File.expand_path(app_dir) + File::SEPARATOR)
    end

    def launcher_script(manifest, app_dir)
      sandbox = manifest.fetch("sandbox", {})
      real_exec = manifest.fetch("installed_executable")
      home_dir = Dir.home
      sandbox_home = File.join(app_dir, "sandbox-home")
      network = sandbox.fetch("network", true)
      home_access = sandbox.fetch("home_access", "documents")

      <<~SH
        #!/usr/bin/env bash
        set -e

        REAL_EXEC=#{Shellwords.escape(real_exec)}
        APP_DIR=#{Shellwords.escape(app_dir)}
        SANDBOX_HOME=#{Shellwords.escape(sandbox_home)}
        HOST_HOME=#{Shellwords.escape(home_dir)}

        if [ "${DEPOT_DISABLE_SANDBOX:-}" = "1" ] || ! command -v bwrap >/dev/null 2>&1; then
          exec "$REAL_EXEC" "$@"
        fi

        mkdir -p "$SANDBOX_HOME"
        args=(--die-with-parent --unshare-ipc --unshare-pid --proc /proc --dev /dev --tmpfs /tmp)
        add_ro() { [ -e "$1" ] && args+=(--ro-bind "$1" "$1"); }
        add_rw() { [ -e "$1" ] && args+=(--bind "$1" "$1"); }

        for path in /usr /bin /sbin /lib /lib64 /etc /opt; do
          add_ro "$path"
        done

        #{home_setup_script(home_access)}
        if [[ "$APP_DIR" == "$HOST_HOME/"* ]]; then
          app_mount_parent="$SANDBOX_HOME/${APP_DIR#"$HOST_HOME/"}"
          mkdir -p "$(dirname "$app_mount_parent")"
        fi
        args+=(--bind "$APP_DIR" "$APP_DIR")
        args+=(--setenv DEPOT_SANDBOXED 1)

        if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -d "$XDG_RUNTIME_DIR" ]; then
          args+=(--bind "$XDG_RUNTIME_DIR" "$XDG_RUNTIME_DIR")
        fi
        if [ -n "${XAUTHORITY:-}" ] && [ -f "$XAUTHORITY" ]; then
          args+=(--ro-bind "$XAUTHORITY" "$XAUTHORITY")
        fi
        if [ -d /tmp/.X11-unix ]; then
          args+=(--ro-bind /tmp/.X11-unix /tmp/.X11-unix)
        fi

        #{network ? "" : "args+=(--unshare-net)"}

        args+=(--chdir #{Shellwords.escape(File.dirname(real_exec))})
        exec bwrap "${args[@]}" "$REAL_EXEC" "$@"
      SH
    end

    def home_setup_script(home_access)
      case home_access
      when "full"
        <<~SH.strip
          args+=(--bind "$HOST_HOME" "$HOST_HOME")
          args+=(--setenv HOME "$HOST_HOME")
        SH
      when "documents"
        <<~SH.strip
          args+=(--bind "$SANDBOX_HOME" "$HOST_HOME")
          args+=(--setenv HOME "$HOST_HOME")
          for dir in Desktop Documents Downloads Pictures Music Videos; do
            if [ -d "$HOST_HOME/$dir" ]; then
              mkdir -p "$SANDBOX_HOME/$dir"
              args+=(--bind "$HOST_HOME/$dir" "$HOST_HOME/$dir")
            fi
          done
        SH
      else
        <<~SH.strip
          args+=(--bind "$SANDBOX_HOME" "$HOST_HOME")
          args+=(--setenv HOME "$HOST_HOME")
        SH
      end
    end

    def rewrite_desktop_entry(manifest)
      desktop_path = manifest["desktop_entry"]
      return unless desktop_path && !desktop_path.empty?

      FileUtils.mkdir_p(File.dirname(desktop_path))
      entry = DesktopEntry.new(
        app_id: manifest.fetch("app_id"),
        name: manifest.fetch("display_name"),
        exec_path: launch_path(manifest),
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
  end
end
