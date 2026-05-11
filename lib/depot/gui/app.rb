# frozen_string_literal: true

require "qt6/qtwidgets"
require_relative "../../depot"
require_relative "drop_panel"
require_relative "main_window"

module Depot
  module GUI
    module App
      module_function

      def run
        app = QApplication.new
        QApplication.set_application_name("Depot")
        QApplication.set_organization_name("Depot")
        QApplication.set_window_icon(QIcon.new(Assets.logo_path)) if File.exist?(Assets.logo_path)
        MainWindow.new.show
        app.exec
      end
    end
  end
end
