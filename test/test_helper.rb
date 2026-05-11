# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "minitest/autorun"
require "tmpdir"
require "depot"

class DepotTest < Minitest::Test
  def with_xdg
    Dir.mktmpdir("depot-test-") do |dir|
      old_env = ENV.to_h
      ENV["XDG_DATA_HOME"] = File.join(dir, "data")
      ENV["XDG_CONFIG_HOME"] = File.join(dir, "config")
      ENV["XDG_STATE_HOME"] = File.join(dir, "state")
      yield dir
    ensure
      ENV.replace(old_env)
    end
  end

  def fake_appimage(path, body = "fake")
    File.binwrite(path, "\x7FELF".b + body)
    File.chmod(0o644, path)
    path
  end

  def fake_deb(path, control_fields: {}, control_files: {}, data_files: {})
    Dir.mktmpdir("depot-deb-build-") do |dir|
      control_dir = File.join(dir, "control")
      data_dir = File.join(dir, "data")
      FileUtils.mkdir_p([control_dir, data_dir])

      control_text = {
        "Package" => "demo-deb",
        "Version" => "1.0.0",
        "Architecture" => "amd64",
        "Maintainer" => "Depot Tests",
        "Description" => "Demo Debian package"
      }.merge(control_fields).map { |key, value| "#{key}: #{value}" }.join("\n") + "\n"
      File.write(File.join(control_dir, "control"), control_text)
      control_files.each do |name, body|
        target = File.join(control_dir, name)
        FileUtils.mkdir_p(File.dirname(target))
        File.write(target, body)
        File.chmod(0o755, target) if %w[preinst postinst prerm postrm config].include?(File.basename(name))
      end

      data_files.each do |name, body|
        target = File.join(data_dir, name)
        FileUtils.mkdir_p(File.dirname(target))
        File.binwrite(target, body)
        File.chmod(0o755, target) if name.start_with?("usr/bin/", "opt/")
      end

      control_tar = File.join(dir, "control.tar.gz")
      data_tar = File.join(dir, "data.tar.gz")
      system("tar", "-czf", control_tar, "-C", control_dir, ".", exception: true)
      system("tar", "-czf", data_tar, "-C", data_dir, ".", exception: true)
      write_ar(
        path,
        "debian-binary" => "2.0\n",
        "control.tar.gz" => File.binread(control_tar),
        "data.tar.gz" => File.binread(data_tar)
      )
    end
    path
  end

  def fake_tar_gz(path, files: {})
    Dir.mktmpdir("depot-tar-build-") do |dir|
      files.each do |name, body|
        target = File.join(dir, name)
        FileUtils.mkdir_p(File.dirname(target))
        File.binwrite(target, body)
        File.chmod(0o755, target) if File.basename(name) == "AppRun" || name.include?("/bin/") || name.end_with?(".sh")
      end
      system("tar", "-czf", path, "-C", dir, ".", exception: true)
    end
    path
  end

  def command_available?(command)
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, command)) }
  end

  def repo_fixture(name)
    matches = Dir[File.expand_path("../fixtures/**/#{name}", __dir__)]
    matches.first || File.expand_path("../fixtures/#{name}", __dir__)
  end

  def with_fake_flatpak(app_id = "org.qbittorrent.qBittorrent")
    Dir.mktmpdir("depot-flatpak-bin-") do |dir|
      log = File.join(dir, "flatpak.log")
      script = File.join(dir, "flatpak")
      File.write(
        script,
        <<~SH
          #!/bin/sh
          set -eu
          cmd="$1"
          shift
          case "$cmd" in
            install)
              mkdir -p "$XDG_DATA_HOME/flatpak/exports/share/applications"
              printf '[Desktop Entry]\\nName=qBittorrent\\nExec=flatpak run #{app_id}\\nIcon=#{app_id}\\nType=Application\\n' > "$XDG_DATA_HOME/flatpak/exports/share/applications/#{app_id}.desktop"
              echo "install $*" >> "$DEPOT_FAKE_FLATPAK_LOG"
              ;;
            info)
              if [ "$2" = "--show-origin" ]; then
                echo "flathub"
              else
                echo "app/#{app_id}/x86_64/stable"
              fi
              ;;
            uninstall)
              rm -f "$XDG_DATA_HOME/flatpak/exports/share/applications/#{app_id}.desktop"
              echo "uninstall $*" >> "$DEPOT_FAKE_FLATPAK_LOG"
              ;;
            update)
              echo "update $*" >> "$DEPOT_FAKE_FLATPAK_LOG"
              ;;
            run)
              echo "run $*" >> "$DEPOT_FAKE_FLATPAK_LOG"
              ;;
          esac
        SH
      )
      File.chmod(0o755, script)
      old_path = ENV["PATH"]
      old_log = ENV["DEPOT_FAKE_FLATPAK_LOG"]
      ENV["PATH"] = "#{dir}#{File::PATH_SEPARATOR}#{old_path}"
      ENV["DEPOT_FAKE_FLATPAK_LOG"] = log
      yield log
    ensure
      ENV["PATH"] = old_path
      ENV["DEPOT_FAKE_FLATPAK_LOG"] = old_log
    end
  end

  def write_ar(path, members)
    File.open(path, "wb") do |file|
      file.write("!<arch>\n")
      members.each do |name, body|
        body = body.b
        ar_name = "#{name}/"
        file.write(format("%-16s%-12d%-6d%-6d%-8o%-10d`\n", ar_name, Time.now.to_i, 0, 0, 0o100644, body.bytesize))
        file.write(body)
        file.write("\n") if body.bytesize.odd?
      end
    end
  end
end
