# frozen_string_literal: true

require_relative "test_helper"

class LauncherTest < DepotTest
  def test_launch_uses_sandbox_launch_path_with_keyword_settings
    Dir.mktmpdir("depot-launcher-test-") do |dir|
      launcher = File.join(dir, "depot-sandbox-launch")
      File.write(launcher, "#!/bin/sh\n")
      File.chmod(0o755, launcher)

      manifest = {
        "app_id" => "demo",
        "backend" => "appimage",
        "installed_executable" => File.join(dir, "demo"),
        "sandbox" => {
          "mode" => "enabled",
          "launcher" => launcher
        }
      }
      settings = { "sandbox_preference" => "ask" }
      spawned = []
      detached = []

      result = Depot::Launcher.launch(
        manifest,
        settings:,
        spawn: ->(*args, **kwargs) {
          spawned << [args, kwargs]
          1234
        },
        detach: ->(pid) { detached << pid }
      )

      assert result.ok?
      assert_equal 1234, result.value
      assert_equal [[[launcher], { pgroup: true }]], spawned
      assert_equal [1234], detached
    end
  end

  def test_launch_returns_error_when_manifest_has_no_executable
    result = Depot::Launcher.launch(
      { "backend" => "appimage" },
      spawn: ->(*) { flunk("spawn should not run") }
    )

    refute result.ok?
    assert_match(/launchable executable/, result.error)
  end

  def test_launch_returns_spawn_errors
    result = Depot::Launcher.launch(
      { "backend" => "appimage", "installed_executable" => "/missing/app" },
      spawn: ->(*) { raise Errno::ENOENT, "/missing/app" }
    )

    refute result.ok?
    assert_match(/Could not launch app/, result.error)
  end
end
