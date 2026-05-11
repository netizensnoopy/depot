# frozen_string_literal: true

require "stringio"
require_relative "test_helper"
require "depot/cli"

class CLITest < DepotTest
  def test_cli_install_list_info_uninstall_flow
    with_xdg do |dir|
      source = fake_appimage(File.join(dir, "Demo.AppImage"))
      out = StringIO.new
      err = StringIO.new
      cli = Depot::CLI.new(stdout: out, stderr: err)

      assert_equal 0, cli.run(["install", source])
      assert_match(/Installed Demo as demo/, out.string)

      out.truncate(0)
      out.rewind
      assert_equal 0, cli.run(["list"])
      assert_match(/demo\tDemo\tappimage/, out.string)

      out.truncate(0)
      out.rewind
      assert_equal 0, cli.run(["info", "demo"])
      assert_match(/App: Demo \(demo\)/, out.string)

      out.truncate(0)
      out.rewind
      assert_equal 0, cli.run(["uninstall", "demo"])
      assert_match(/Uninstalled demo/, out.string)
    end
  end

  def test_cli_doctor_reports_json
    with_xdg do
      out = StringIO.new
      err = StringIO.new
      cli = Depot::CLI.new(stdout: out, stderr: err)

      assert_equal 0, cli.run(["doctor", "--json"])
      report = JSON.parse(out.string)
      assert report.key?("tools")
      assert report.key?("paths")
      assert report.key?("manifests")
    end
  end

  def test_cli_updates_app
    with_xdg do |dir|
      source = fake_appimage(File.join(dir, "Demo.AppImage"))
      out = StringIO.new
      err = StringIO.new
      cli = Depot::CLI.new(stdout: out, stderr: err)

      assert_equal 0, cli.run(["install", source])
      out.truncate(0)
      out.rewind

      assert_equal 0, cli.run(["update", "demo"])
      assert_match(/Updated Demo \(demo\)/, out.string)
    end
  end

  def test_cli_sets_update_source
    with_xdg do |dir|
      source = fake_appimage(File.join(dir, "Demo.AppImage"))
      out = StringIO.new
      err = StringIO.new
      cli = Depot::CLI.new(stdout: out, stderr: err)

      assert_equal 0, cli.run(["install", source])
      out.truncate(0)
      out.rewind

      assert_equal 0, cli.run(["update-source", "demo", "https://example.com/Demo.AppImage"])
      assert_match(/Set update source for demo/, out.string)
      manifest = Depot::ManifestStore.new.find("demo")
      assert_equal "https://example.com/Demo.AppImage", manifest.dig("update", "source")
    end
  end

  def test_cli_sets_sandbox_mode
    with_xdg do |dir|
      source = fake_appimage(File.join(dir, "Demo.AppImage"))
      out = StringIO.new
      err = StringIO.new
      cli = Depot::CLI.new(stdout: out, stderr: err)

      assert_equal 0, cli.run(["install", source])
      out.truncate(0)
      out.rewind

      assert_equal 0, cli.run(["sandbox", "demo", "enabled"])
      assert_match(/Set sandbox for demo to enabled/, out.string)
      manifest = Depot::ManifestStore.new.find("demo")
      assert_equal "enabled", manifest.dig("sandbox", "mode")
      assert File.executable?(manifest.dig("sandbox", "launcher"))
    end
  end
end
