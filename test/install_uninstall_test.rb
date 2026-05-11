# frozen_string_literal: true

require_relative "test_helper"

class InstallUninstallTest < DepotTest
  def test_installs_appimage_user_locally_and_uninstalls_manifest_files
    with_xdg do |dir|
      source = fake_appimage(File.join(dir, "Cool Tool.AppImage"))

      install = Depot::Installer.install(source)

      assert install.ok?, install.error
      manifest = install.value
      assert_equal "cool-tool", manifest.fetch("app_id")
      assert File.exist?(manifest.fetch("installed_executable"))
      assert File.executable?(manifest.fetch("installed_executable"))
      assert File.exist?(manifest.fetch("desktop_entry"))
      assert File.exist?(manifest.fetch("manifest_path"))
      assert_includes File.read(manifest.fetch("desktop_entry")), "X-Depot-AppID=cool-tool"

      uninstall = Depot::Uninstaller.uninstall("cool-tool")

      assert uninstall.ok?, uninstall.error
      refute File.exist?(manifest.fetch("installed_executable"))
      refute File.exist?(manifest.fetch("desktop_entry"))
      refute File.exist?(manifest.fetch("manifest_path"))
    end
  end

  def test_uninstall_ignores_manifest_files_outside_allowed_roots
    with_xdg do |dir|
      outside = File.join(dir, "outside.txt")
      File.write(outside, "do not delete")
      store = Depot::ManifestStore.new
      store.write(
        "app_id" => "unsafe",
        "display_name" => "Unsafe",
        "created_files" => [outside],
        "created_dirs" => []
      )

      result = Depot::Uninstaller.uninstall("unsafe")

      assert result.ok?
      assert File.exist?(outside)
      refute Depot::ManifestStore.new.find("unsafe")
    end
  end

  def test_appimage_icon_discovery_prefers_desktop_icon_name
    Dir.mktmpdir("depot-icons-") do |root|
      FileUtils.mkdir_p(File.join(root, "usr", "share", "icons", "hicolor", "256x256", "apps"))
      FileUtils.mkdir_p(File.join(root, "data", "assets"))
      preferred = File.join(root, "usr", "share", "icons", "hicolor", "256x256", "apps", "localsend.png")
      fallback = File.join(root, "data", "assets", "logo-512.png")
      File.binwrite(preferred, "preferred")
      File.binwrite(fallback, "fallback")

      backend = Depot::Backends::AppImage.allocate
      icons = backend.send(:find_icons, root, "localsend")

      assert_equal preferred, icons.first
      assert_includes icons, fallback
    end
  end

  def test_customizer_renames_changes_icon_and_resets_desktop_entry
    with_xdg do |dir|
      app_dir = File.join(Depot::Paths.apps_dir, "demo")
      FileUtils.mkdir_p(app_dir)
      executable = File.join(app_dir, "Demo.AppImage")
      File.binwrite(executable, "\x7FELF".b)
      desktop = File.join(Depot::Paths.desktop_entries_dir, "depot-demo.desktop")
      icon = File.join(dir, "custom.png")
      File.binwrite(icon, "png")
      FileUtils.mkdir_p(File.dirname(desktop))

      store = Depot::ManifestStore.new
      store.write(
        "app_id" => "demo",
        "display_name" => "Demo",
        "backend" => "appimage",
        "install_source" => executable,
        "installed_executable" => executable,
        "desktop_entry" => desktop,
        "icons" => [File.join(Depot::Paths.icon_root, "256x256", "apps", "demo.png")],
        "created_files" => [executable, desktop],
        "created_dirs" => [app_dir],
        "installed_at" => "2026-05-10T00:00:00Z"
      )

      customizer = Depot::AppCustomizer.new(store:)
      rename = customizer.rename("demo", "Better Demo")
      assert rename.ok?, rename.error
      assert_includes File.read(desktop), "Name=Better Demo"

      change_icon = customizer.change_icon("demo", icon)
      assert change_icon.ok?, change_icon.error
      manifest = store.find("demo")
      assert File.exist?(manifest.fetch("custom_icon").fetch("path"))
      assert_includes File.read(desktop), "Icon=#{manifest.fetch("custom_icon").fetch("path")}"

      reset = customizer.reset("demo")
      assert reset.ok?, reset.error
      manifest = store.find("demo")
      assert_equal "Demo", manifest.fetch("display_name")
      refute manifest.key?("custom_icon")
      assert_includes File.read(desktop), "Name=Demo"
      assert_includes File.read(desktop), "Icon=demo"
    end
  end

  def test_sandbox_can_enable_portable_app_launcher
    with_xdg do |dir|
      source = fake_appimage(File.join(dir, "Sandboxed.AppImage"))
      install = Depot::Installer.install(source)
      assert install.ok?, install.error
      manifest = install.value

      result = Depot::Sandbox.set(
        manifest.fetch("app_id"),
        {
          "mode" => "enabled",
          "profile" => "balanced",
          "home_access" => "isolated",
          "network" => false
        }
      )

      assert result.ok?, result.error
      updated = result.value
      launcher = updated.fetch("sandbox").fetch("launcher")
      assert File.executable?(launcher)
      assert_includes File.read(launcher), "bwrap"
      assert_includes File.read(launcher), "--unshare-net"
      assert_includes File.read(updated.fetch("desktop_entry")), "Exec=\"#{launcher}\""
      assert_equal launcher, Depot::Sandbox.launch_path(updated)
    end
  end

  def test_sandbox_disabled_restores_normal_launcher
    with_xdg do |dir|
      source = fake_appimage(File.join(dir, "Sandboxed.AppImage"))
      install = Depot::Installer.install(source, settings: { "sandbox_preference" => "prefer-on" })
      assert install.ok?, install.error
      manifest = install.value
      assert File.executable?(manifest.dig("sandbox", "launcher"))

      result = Depot::Sandbox.set(manifest.fetch("app_id"), { "mode" => "disabled" })

      assert result.ok?, result.error
      updated = result.value
      refute updated.fetch("sandbox").key?("launcher")
      assert_equal manifest.fetch("installed_executable"), Depot::Sandbox.launch_path(updated)
      assert_includes File.read(updated.fetch("desktop_entry")), "Exec=\"#{manifest.fetch("installed_executable")}\""
    end
  end

  def test_installs_deb_by_portable_extraction
    with_xdg do |dir|
      source = fake_deb(
        File.join(dir, "Demo.deb"),
        control_fields: { "Package" => "demo-deb", "Version" => "2.4.0" },
        data_files: {
          "usr/bin/demo" => "#!/bin/sh\n",
          "usr/share/applications/demo.desktop" => "[Desktop Entry]\nName=Demo Deb\nExec=/usr/bin/demo --hello\nIcon=demo\nType=Application\n",
          "usr/share/icons/hicolor/128x128/apps/demo.png" => "png"
        }
      )

      install = Depot::Installer.install(source)

      assert install.ok?, install.error
      manifest = install.value
      assert_equal "deb-portable", manifest.fetch("backend")
      assert_equal "Demo Deb", manifest.fetch("display_name")
      assert File.exist?(manifest.fetch("installed_executable"))
      desktop = File.read(manifest.fetch("desktop_entry"))
      assert_includes desktop, "X-Depot-AppID=#{manifest.fetch("app_id")}"
      assert_includes desktop, "Icon=#{manifest.fetch("app_id")}"
      assert_includes desktop, "root/usr/bin/demo"

      uninstall = Depot::Uninstaller.uninstall(manifest.fetch("app_id"))

      assert uninstall.ok?, uninstall.error
      refute Dir.exist?(File.join(Depot::Paths.apps_dir, manifest.fetch("app_id")))
      refute File.exist?(manifest.fetch("desktop_entry"))
    end
  end

  def test_deb_install_uses_fallback_icon_when_icon_is_not_in_hicolor
    with_xdg do |dir|
      png = "\x89PNG\r\n\x1A\n".b + ("\0" * 8) + [32, 32].pack("NN") + "rest"
      source = fake_deb(
        File.join(dir, "Cursor.deb"),
        control_fields: { "Package" => "cursor", "Version" => "2.6.21" },
        data_files: {
          "usr/bin/cursor" => "#!/bin/sh\n",
          "usr/share/applications/cursor-url-handler.desktop" => "[Desktop Entry]\nName=Cursor - URL Handler\nExec=/usr/bin/cursor --open-url %U\nIcon=co.anysphere.cursor\nType=Application\nNoDisplay=true\n",
          "usr/share/applications/cursor.desktop" => "[Desktop Entry]\nName=Cursor\nExec=/usr/bin/cursor %F\nIcon=co.anysphere.cursor\nType=Application\n",
          "usr/share/cursor/resources/app/resources/linux/code.png" => png
        }
      )

      install = Depot::Installer.install(source)

      assert install.ok?, install.error
      manifest = install.value
      assert_equal "Cursor", manifest.fetch("display_name")
      refute_empty manifest.fetch("icons")
      assert_includes File.read(manifest.fetch("desktop_entry")), "Icon=#{manifest.fetch("app_id")}"
      refute_includes File.read(manifest.fetch("desktop_entry")), "NoDisplay=true"
    end
  end

  def test_installs_tar_gz_archive_with_existing_desktop_entry
    with_xdg do |dir|
      png = "\x89PNG\r\n\x1A\n".b + ("\0" * 8) + [64, 64].pack("NN") + "rest"
      source = fake_tar_gz(
        File.join(dir, "DemoTool.tar.gz"),
        files: {
          "DemoTool/AppRun" => "#!/bin/sh\n",
          "DemoTool/demo.desktop" => "[Desktop Entry]\nName=Demo Tool\nExec=AppRun --demo\nIcon=demo\nType=Application\n",
          "DemoTool/icon.png" => png
        }
      )

      install = Depot::Installer.install(source)

      assert install.ok?, install.error
      manifest = install.value
      assert_equal "archive-portable", manifest.fetch("backend")
      assert_equal "Demo Tool", manifest.fetch("display_name")
      assert File.exist?(manifest.fetch("installed_executable"))
      assert File.exist?(manifest.fetch("desktop_entry"))
      refute_empty manifest.fetch("icons")
      desktop = File.read(manifest.fetch("desktop_entry"))
      assert_includes desktop, "X-Depot-AppID=#{manifest.fetch("app_id")}"
      assert_includes desktop, "root/DemoTool/AppRun"
      assert_includes desktop, "Icon=#{manifest.fetch("app_id")}"
    end
  end

  def test_installs_tar_gz_archive_by_generating_desktop_entry
    with_xdg do |dir|
      source = fake_tar_gz(
        File.join(dir, "LooseApp.tar.gz"),
        files: {
          "LooseApp/bin/looseapp" => "#!/bin/sh\n"
        }
      )

      install = Depot::Installer.install(source)

      assert install.ok?, install.error
      manifest = install.value
      assert_equal "archive-portable", manifest.fetch("backend")
      assert File.exist?(manifest.fetch("desktop_entry"))
      assert_includes File.read(manifest.fetch("desktop_entry")), "Name=Looseapp"
      assert_includes File.read(manifest.fetch("desktop_entry")), "bin/looseapp"
    end
  end

  def test_installs_rpm_by_portable_extraction
    skip "sample RPM fixture is not present" unless File.exist?(repo_fixture("Modrinth App-0.13.14-1.x86_64.rpm"))
    skip "bsdtar is required to install RPM payloads" unless command_available?("bsdtar")

    with_xdg do
      source = repo_fixture("Modrinth App-0.13.14-1.x86_64.rpm")

      install = Depot::Installer.install(source)

      assert install.ok?, install.error
      manifest = install.value
      assert_equal "rpm-portable", manifest.fetch("backend")
      assert_equal "Modrinth App", manifest.fetch("display_name")
      assert_equal "modrinth-app", manifest.fetch("package").fetch("Name")
      assert File.exist?(manifest.fetch("installed_executable"))
      assert File.executable?(manifest.fetch("installed_executable"))
      assert File.exist?(manifest.fetch("desktop_entry"))
      refute_empty manifest.fetch("icons")
      desktop = File.read(manifest.fetch("desktop_entry"))
      assert_includes desktop, "X-Depot-AppID=#{manifest.fetch("app_id")}"
      assert_includes desktop, "root/usr/bin/ModrinthApp"
      assert_includes desktop, "Icon=#{manifest.fetch("app_id")}"

      uninstall = Depot::Uninstaller.uninstall(manifest.fetch("app_id"))

      assert uninstall.ok?, uninstall.error
      refute Dir.exist?(File.join(Depot::Paths.apps_dir, manifest.fetch("app_id")))
      refute File.exist?(manifest.fetch("desktop_entry"))
    end
  end

  def test_installs_and_uninstalls_flatpakref_through_flatpak
    source = repo_fixture("org.qbittorrent.qBittorrent.flatpakref")
    skip "sample flatpakref fixture is not present" unless File.exist?(source)

    with_xdg do
      with_fake_flatpak do |log|
        install = Depot::Installer.install(source)

        assert install.ok?, install.error
        manifest = install.value
        assert_equal "flatpak", manifest.fetch("backend")
        assert_equal "org.qbittorrent.qBittorrent", manifest.fetch("flatpak").fetch("app_id")
        assert_equal "qBittorrent", manifest.fetch("display_name")
        assert File.exist?(manifest.fetch("installed_executable"))
        assert File.executable?(manifest.fetch("installed_executable"))
        assert File.exist?(manifest.fetch("desktop_entry"))
        assert_includes File.read(log), "install --user --noninteractive -y --or-update --from #{source}"

        uninstall = Depot::Uninstaller.uninstall(manifest.fetch("app_id"))

        assert uninstall.ok?, uninstall.error
        assert_includes File.read(log), "uninstall --user --noninteractive -y org.qbittorrent.qBittorrent"
        refute Depot::ManifestStore.new.find(manifest.fetch("app_id"))
      end
    end
  end
end
