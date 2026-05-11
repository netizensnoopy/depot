# frozen_string_literal: true

require "fileutils"

module Depot
  module Paths
    module_function

    def data_home
      ENV.fetch("XDG_DATA_HOME", File.join(Dir.home, ".local", "share"))
    end

    def config_home
      ENV.fetch("XDG_CONFIG_HOME", File.join(Dir.home, ".config"))
    end

    def state_home
      ENV.fetch("XDG_STATE_HOME", File.join(Dir.home, ".local", "state"))
    end

    def data_dir
      File.join(data_home, "depot")
    end

    def config_dir
      File.join(config_home, "depot")
    end

    def state_dir
      File.join(state_home, "depot")
    end

    def apps_dir
      File.join(data_dir, "apps")
    end

    def manifests_dir
      File.join(data_dir, "manifests")
    end

    def desktop_entries_dir
      File.join(data_home, "applications")
    end

    def icon_root
      File.join(data_home, "icons", "hicolor")
    end

    def settings_path
      File.join(config_dir, "settings.json")
    end

    def ensure_base_dirs
      FileUtils.mkdir_p([data_dir, config_dir, state_dir, apps_dir, manifests_dir, desktop_entries_dir])
    end
  end
end
