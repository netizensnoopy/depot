# frozen_string_literal: true

require_relative "util"

module Depot
  class DesktopEntry
    attr_reader :app_id, :name, :exec_path, :icon_name

    def initialize(app_id:, name:, exec_path:, icon_name: nil)
      @app_id = app_id
      @name = name
      @exec_path = exec_path
      @icon_name = icon_name
    end

    def contents
      lines = [
        "[Desktop Entry]",
        "Type=Application",
        "Version=1.0",
        "Name=#{escape(name)}",
        "Exec=#{Util.desktop_exec_quote(exec_path)}",
        "Terminal=false",
        "Categories=Utility;",
        "X-Depot-AppID=#{escape(app_id)}"
      ]
      lines << "Icon=#{escape(icon_name)}" if icon_name && !icon_name.empty?
      lines.join("\n") + "\n"
    end

    private

    def escape(value)
      value.to_s.gsub("\\", "\\\\\\").gsub("\n", "\\n")
    end
  end
end
