# frozen_string_literal: true

require_relative "test_helper"

class UpdaterTest < DepotTest
  def test_updates_flatpak_through_flatpak
    source = repo_fixture("org.qbittorrent.qBittorrent.flatpakref")
    skip "sample flatpakref fixture is not present" unless File.exist?(source)

    with_xdg do
      with_fake_flatpak do |log|
        install = Depot::Installer.install(source)
        assert install.ok?, install.error

        update = Depot::Updater.update(install.value.fetch("app_id"))

        assert update.ok?, update.error
        assert_includes File.read(log), "update --user --noninteractive -y org.qbittorrent.qBittorrent"
        manifest = Depot::ManifestStore.new.find(install.value.fetch("app_id"))
        assert_equal "flatpak", manifest.fetch("update").fetch("mechanism")
        assert_equal "updated", manifest.fetch("update").fetch("status")
      end
    end
  end

  def test_updates_portable_app_by_reinstalling_source
    with_xdg do |dir|
      source = fake_appimage(File.join(dir, "Demo.AppImage"))
      install = Depot::Installer.install(source)
      assert install.ok?, install.error

      update = Depot::Updater.update(install.value.fetch("app_id"))

      assert update.ok?, update.error
      manifest = Depot::ManifestStore.new.find(install.value.fetch("app_id"))
      assert_equal "reinstall-source", manifest.fetch("update").fetch("mechanism")
      assert_equal "updated", manifest.fetch("update").fetch("status")
      assert File.exist?(manifest.fetch("installed_executable"))
    end
  end

  def test_sets_https_update_source
    with_xdg do |dir|
      source = fake_appimage(File.join(dir, "Demo.AppImage"))
      install = Depot::Installer.install(source)
      assert install.ok?, install.error

      result = Depot::Updater.set_source(install.value.fetch("app_id"), "https://example.com/Demo.AppImage")

      assert result.ok?, result.error
      manifest = Depot::ManifestStore.new.find(install.value.fetch("app_id"))
      assert_equal "https://example.com/Demo.AppImage", manifest.dig("update", "source")
      assert_equal "url-download", manifest.dig("update", "mechanism")
    end
  end

  def test_rejects_non_https_update_source
    with_xdg do |dir|
      source = fake_appimage(File.join(dir, "Demo.AppImage"))
      install = Depot::Installer.install(source)
      assert install.ok?, install.error

      result = Depot::Updater.set_source(install.value.fetch("app_id"), "http://example.com/Demo.AppImage")

      refute result.ok?
      assert_match(/https/, result.error)
    end
  end

  def test_updates_from_https_url_after_inspecting_download
    with_xdg do |dir|
      source = fake_appimage(File.join(dir, "Demo.AppImage"), "v1")
      downloaded = fake_appimage(File.join(dir, "DownloadedDemo.AppImage"), "v2")
      install = Depot::Installer.install(source)
      assert install.ok?, install.error
      assert Depot::Updater.set_source(install.value.fetch("app_id"), "https://example.com/DownloadedDemo.AppImage").ok?

      with_stubbed_update_download(downloaded) do
        update = Depot::Updater.update(install.value.fetch("app_id"))
        assert update.ok?, update.error
      end

      records = Depot::ManifestStore.new.all
      assert_equal 1, records.length
      manifest = records.first
      assert_equal "url-download", manifest.dig("update", "mechanism")
      assert_equal "https://example.com/DownloadedDemo.AppImage", manifest.fetch("install_source")
      assert_equal "https://example.com/DownloadedDemo.AppImage", manifest.dig("update", "source")
      assert_equal Depot::Util.sha256(downloaded), manifest.dig("update", "last_download_sha256")
      assert File.exist?(manifest.fetch("installed_executable"))
    end
  end

  def test_url_update_rejects_package_family_change_before_uninstall
    with_xdg do |dir|
      source = fake_appimage(File.join(dir, "Demo.AppImage"), "v1")
      downloaded = fake_tar_gz(File.join(dir, "Demo.tar.gz"), files: { "demo/AppRun" => "#!/bin/sh\n" })
      install = Depot::Installer.install(source)
      assert install.ok?, install.error
      assert Depot::Updater.set_source(install.value.fetch("app_id"), "https://example.com/Demo.tar.gz").ok?

      with_stubbed_update_download(downloaded) do
        update = Depot::Updater.update(install.value.fetch("app_id"))
        refute update.ok?
        assert_match(/will not switch package families/, update.error)
      end

      manifest = Depot::ManifestStore.new.find(install.value.fetch("app_id"))
      assert manifest
      assert File.exist?(manifest.fetch("installed_executable"))
      assert_equal "appimage", manifest.fetch("backend")
    end
  end

  def test_updates_respect_settings_toggle
    with_xdg do |dir|
      Depot::Settings.new.save("updates_enabled" => false)
      source = fake_appimage(File.join(dir, "Demo.AppImage"))
      install = Depot::Installer.install(source)
      assert install.ok?, install.error

      update = Depot::Updater.update(install.value.fetch("app_id"))

      refute update.ok?
      assert_match(/disabled/, update.error)
    end
  end

  private

  def with_stubbed_update_download(path)
    original = Depot::UpdateDownloader.method(:download)
    Depot::UpdateDownloader.singleton_class.define_method(:download) do |url, **_kwargs, &block|
      block.call(
        path,
        {
          "url" => url,
          "size" => File.size(path),
          "sha256" => Depot::Util.sha256(path)
        }
      )
    end
    yield
  ensure
    Depot::UpdateDownloader.singleton_class.define_method(:download, original)
  end
end
