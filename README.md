# Depot

Depot is a Ruby + Qt6 Linux application installer and desktop integration layer. It presents software as one installable thing while the internals choose the right backend. The current build supports AppImage installation, portable `.deb` extraction, portable `.rpm` extraction, `.flatpakref` installation, and portable tar archive integration through the shared CLI/GUI core.

## Run

```sh
bundle install
./bin/setup-rubyqt6
./bin/depot --help
./bin/depot-gui
```

The CLI works without Qt loading. The GUI requires the local RubyQt6 native extensions built by `bin/setup-rubyqt6`.

## Commands

```sh
./bin/depot inspect ./App.AppImage
./bin/depot install ./App.AppImage
./bin/depot inspect ./App.deb
./bin/depot install ./App.deb
./bin/depot inspect ./App.rpm
./bin/depot install ./App.rpm
./bin/depot inspect ./App.flatpakref
./bin/depot install ./App.flatpakref
./bin/depot inspect ./App.tar.gz
./bin/depot install ./App.tar.gz
./bin/depot list
./bin/depot info app
./bin/depot uninstall app
./bin/depot update app
./bin/depot update --all
./bin/depot update-source app https://example.com/App.AppImage
./bin/depot sandbox app enabled
./bin/depot doctor
./bin/depot settings
```

Installed applications are copied under `~/.local/share/depot/apps`, manifests live under `~/.local/share/depot/manifests`, and desktop entries are created under `~/.local/share/applications`.

Sample packages used by tests and local backend checks live under `fixtures/`, grouped by format.

`.deb` support is intentionally universal-first: Depot parses Debian packages itself, extracts installable files under Depot's user-local app directory, rewrites desktop launchers/icons, and does not require or call `apt`, `dpkg`, `sudo`, or Debian maintainer scripts. Packages that rely on Debian-family dependencies, services, or maintainer-script side effects may still need native distro installation or a future compatibility runtime.

`.rpm` support follows the same universal-first model: Depot parses RPM headers for package metadata, requirements, scriptlets, payload format, desktop entries, and icons, then extracts the payload under Depot's user-local app directory through libarchive/`bsdtar`. It does not require or call `rpm`, `dnf`, `zypper`, `sudo`, or RPM scriptlets. Packages that rely on RPM-family dependencies, services, users, policies, or scriptlet side effects may still need native distro installation or a future compatibility runtime.

`.flatpakref` support uses Flatpak as the backend instead of unpacking the application itself. Depot parses the ref for transparency, runs `flatpak install --user --from`, records a Depot manifest, creates a small launch wrapper, and calls `flatpak uninstall --user` when removing the app. Flatpak remains responsible for downloads, remotes, runtime dependencies, sandboxing, exported desktop entries, and updates.

Tar archive support is also portable-first: Depot inspects `.tar.gz` / `.tgz` archives, extracts them user-locally, reuses or generates desktop launchers, copies icons when possible, and never runs installer scripts from the archive.

Updates are enabled by default and can be disabled through settings. Flatpak apps update through `flatpak update --user`; AppImage, `.deb`, `.rpm`, and tar archive installs update by reinstalling from their original source file when that file is still available. You can also attach an HTTPS update URL with `depot update-source APP_ID HTTPS_URL`; Depot streams the download to a temporary file, enforces a size limit, inspects the package before uninstalling anything, and refuses updates that switch package families.

Sandboxing is managed globally in Settings and per app from the Installed page. Portable AppImage, `.deb`, `.rpm`, and tar archive installs use a generated Bubblewrap launcher when sandboxing is enabled; Flatpak apps keep using Flatpak's own sandbox and permission model. If `bwrap` is missing, Depot falls back to the normal launcher instead of making the app unlaunchable.

`depot doctor` checks required helper tools, Depot data paths, installed manifests, launchers, desktop entries, and original install sources.
