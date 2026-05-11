# frozen_string_literal: true

require_relative "test_helper"

class InspectorTest < DepotTest
  def test_detects_appimage_by_extension_and_elf_header
    with_xdg do |dir|
      path = fake_appimage(File.join(dir, "Example.AppImage"))

      result = Depot::Inspector.inspect(path)

      assert result.ok?
      assert_equal "appimage", result.value.format
      assert_equal "high", result.value.confidence
      assert_equal false, result.value.executable
      assert result.value.sha256
    end
  end

  def test_reports_unknown_regular_file
    with_xdg do |dir|
      path = File.join(dir, "notes.txt")
      File.write(path, "hello")

      result = Depot::Inspector.inspect(path)

      assert result.ok?
      assert_equal "unknown", result.value.format
      assert_includes result.value.risks, "This format does not have an installer backend yet."
    end
  end

  def test_inspects_debian_package_without_dpkg
    with_xdg do |dir|
      path = fake_deb(
        File.join(dir, "Demo.deb"),
        control_fields: { "Package" => "demo-deb", "Depends" => "libgtk-3-0" },
        control_files: { "postinst" => "#!/bin/sh\ntrue\n" },
        data_files: {
          "usr/bin/demo" => "#!/bin/sh\n",
          "usr/share/applications/demo.desktop" => "[Desktop Entry]\nName=Demo\nExec=/usr/bin/demo\nIcon=demo\nType=Application\n"
        }
      )

      result = Depot::Inspector.inspect(path)

      assert result.ok?, result.error
      assert_equal "deb", result.value.format
      assert_equal "demo-deb", result.value.metadata.fetch("package")
      assert_equal ["postinst"], result.value.metadata.fetch("maintainer_scripts")
      assert_equal "usr/share/applications/demo.desktop", result.value.metadata.fetch("primary_desktop_entry")
      assert result.value.warnings.any? { |warning| warning.include?("Debian package") }
    end
  end

  def test_debian_package_prefers_visible_desktop_entry
    with_xdg do |dir|
      path = fake_deb(
        File.join(dir, "Cursor.deb"),
        control_fields: { "Package" => "cursor" },
        data_files: {
          "usr/bin/cursor" => "#!/bin/sh\n",
          "usr/share/applications/cursor-url-handler.desktop" => "[Desktop Entry]\nName=Cursor - URL Handler\nExec=/usr/bin/cursor --open-url %U\nIcon=co.anysphere.cursor\nType=Application\nNoDisplay=true\n",
          "usr/share/applications/cursor.desktop" => "[Desktop Entry]\nName=Cursor\nExec=/usr/bin/cursor %F\nIcon=co.anysphere.cursor\nType=Application\n"
        }
      )

      result = Depot::Inspector.inspect(path)

      assert result.ok?, result.error
      assert_equal "usr/share/applications/cursor.desktop", result.value.metadata.fetch("primary_desktop_entry")
    end
  end

  def test_inspects_tar_gz_portable_archive
    with_xdg do |dir|
      path = fake_tar_gz(
        File.join(dir, "DemoTool.tar.gz"),
        files: {
          "DemoTool/AppRun" => "#!/bin/sh\n",
          "DemoTool/demo.desktop" => "[Desktop Entry]\nName=Demo Tool\nExec=AppRun\nIcon=demo\nType=Application\n",
          "DemoTool/icon.png" => "\x89PNG\r\n\x1A\n".b + ("\0" * 8) + [64, 64].pack("NN") + "rest",
          "DemoTool/install.sh" => "#!/bin/sh\n"
        }
      )

      result = Depot::Inspector.inspect(path)

      assert result.ok?, result.error
      assert_equal "tar.gz", result.value.format
      assert_equal "DemoTool", result.value.metadata.fetch("archive_root")
      assert_equal ["DemoTool/demo.desktop"], result.value.metadata.fetch("desktop_entries")
      assert_includes result.value.metadata.fetch("executable_candidates"), "DemoTool/AppRun"
      assert_includes result.value.metadata.fetch("script_entries"), "DemoTool/install.sh"
      assert result.value.warnings.any? { |warning| warning.include?("not a formal Linux package") }
    end
  end

  def test_inspects_real_rpm_package_without_rpm_tools
    skip "sample RPM fixture is not present" unless File.exist?(repo_fixture("Modrinth App-0.13.14-1.x86_64.rpm"))
    skip "bsdtar is required to inspect RPM payloads" unless command_available?("bsdtar")

    result = Depot::Inspector.inspect(repo_fixture("Modrinth App-0.13.14-1.x86_64.rpm"))

    assert result.ok?, result.error
    assert_equal "rpm", result.value.format
    assert_equal "high", result.value.confidence
    assert_equal "modrinth-app", result.value.metadata.fetch("package")
    assert_equal "0.13.14", result.value.metadata.fetch("version")
    assert_equal "1", result.value.metadata.fetch("release")
    assert_equal "x86_64", result.value.metadata.fetch("architecture")
    assert_equal "cpio", result.value.metadata.fetch("payload_format")
    assert_equal "gzip", result.value.metadata.fetch("payload_compressor")
    assert_equal "usr/share/applications/Modrinth App.desktop", result.value.metadata.fetch("primary_desktop_entry")
    assert_includes result.value.metadata.fetch("executable_candidates"), "usr/bin/ModrinthApp"
    assert result.value.warnings.any? { |warning| warning.include?("RPM package") }
  end

  def test_inspects_rpm_scriptlets
    skip "sample RPM fixture is not present" unless File.exist?(repo_fixture("1password-latest.rpm"))
    skip "bsdtar is required to inspect RPM payloads" unless command_available?("bsdtar")

    result = Depot::Inspector.inspect(repo_fixture("1password-latest.rpm"))

    assert result.ok?, result.error
    assert_equal "rpm", result.value.format
    assert_equal "1password", result.value.metadata.fetch("package")
    assert_equal "xz", result.value.metadata.fetch("payload_compressor")
    assert_includes result.value.metadata.fetch("scriptlets"), "postinstall"
    assert_includes result.value.metadata.fetch("scriptlets"), "postuninstall"
  end

  def test_inspects_flatpakref
    source = repo_fixture("org.qbittorrent.qBittorrent.flatpakref")
    skip "sample flatpakref fixture is not present" unless File.exist?(source)

    result = Depot::Inspector.inspect(source)

    assert result.ok?, result.error
    assert_equal "flatpakref", result.value.format
    assert_equal "high", result.value.confidence
    assert_equal "org.qbittorrent.qBittorrent", result.value.metadata.fetch("name")
    assert_equal "stable", result.value.metadata.fetch("branch")
    assert_equal "flathub", result.value.metadata.fetch("suggest_remote_name")
    assert_equal false, result.value.metadata.fetch("is_runtime")
    assert_equal true, result.value.metadata.fetch("gpg_key_present")
    assert result.value.warnings.any? { |warning| warning.include?("Flatpak reference") }
  end
end
