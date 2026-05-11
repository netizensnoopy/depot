# frozen_string_literal: true

require_relative "test_helper"

class SettingsTest < DepotTest
  def test_saves_and_loads_settings
    with_xdg do
      settings = Depot::Settings.new

      saved = settings.save("theme" => "dark", "desktop_integration" => false)
      loaded = settings.load

      assert_equal "dark", saved.fetch("theme")
      assert_equal false, loaded.fetch("desktop_integration")
      assert_equal true, loaded.fetch("updates_enabled")
      assert_equal "normal", loaded.fetch("warning_verbosity")
    end
  end
end
