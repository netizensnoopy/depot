# frozen_string_literal: true

require "uri"
require_relative "packages/archive"
require_relative "packages/deb"
require_relative "packages/flatpak_ref"
require_relative "inspection"
require_relative "packages/rpm"
require_relative "result"
require_relative "util"

module Depot
  class Inspector
    APPIMAGE_EXT = /\.appimage\z/i
    DEB_EXT = /\.deb\z/i
    RPM_EXT = /\.rpm\z/i
    FLATPAKREF_EXT = /\.flatpakref\z/i
    ARCHIVE_EXT = /\.(tar\.gz|tgz|tar\.xz|txz|tar\.zst|tzst)\z/i
    ELF_MAGIC = "\x7FELF".b.freeze

    def self.inspect(input, checksum: true)
      new.inspect(input, checksum:)
    end

    def inspect(input, checksum: true)
      source = input.to_s
      uri = parse_uri(source)
      return inspect_url(uri) if uri&.absolute?
      return Result.err("Path does not exist: #{source}") unless File.exist?(source)
      return Result.err("Input is not a regular file: #{source}") unless File.file?(source)

      Result.ok(file_inspection(source, checksum:))
    end

    private

    def inspect_url(uri)
      warnings = ["URL installs are planned; this build installs local files through available backends."]
      inspection = Inspection.new(
        input: uri.to_s,
        format: format_from_name(uri.path),
        confidence: "low",
        display_name: File.basename(uri.path),
        sha256: nil,
        size: nil,
        executable: false,
        metadata: {},
        warnings:,
        risks: ["Depot cannot verify remote content until it is downloaded."]
      )
      Result.ok(inspection, warnings:)
    end

    def file_inspection(path, checksum: true)
      extension_match = path.match?(APPIMAGE_EXT)
      deb_extension_match = path.match?(DEB_EXT)
      rpm_extension_match = path.match?(RPM_EXT)
      flatpakref_extension_match = path.match?(FLATPAKREF_EXT)
      archive_extension_match = path.match?(ARCHIVE_EXT)
      elf = elf?(path)
      deb_package = deb_extension_match ? DebPackage.new(path) : nil
      deb_valid = deb_package&.valid?
      rpm_package = rpm_extension_match ? RpmPackage.new(path) : nil
      rpm_valid = rpm_package&.valid?
      flatpak_ref = flatpakref_extension_match ? FlatpakRef.new(path) : nil
      flatpakref_valid = flatpak_ref&.valid?
      archive_package = archive_extension_match ? ArchivePackage.new(path) : nil
      archive_valid = archive_package&.valid?
      warnings = []
      risks = []
      metadata = {}
      display_name = if archive_valid
                       archive_package.display_name
                     elsif rpm_valid
                       rpm_package.display_name
                     elsif flatpakref_valid
                       flatpak_ref.display_name
                     elsif rpm_extension_match
                       File.basename(path, ".rpm")
                     elsif flatpakref_extension_match
                       File.basename(path, ".flatpakref")
                     elsif archive_extension_match
                       File.basename(path).sub(/\.(tar\.gz|tgz|tar\.xz|txz|tar\.zst|tzst)\z/i, "")
                     else
                       File.basename(path, File.extname(path))
                     end

      format = if extension_match && elf
                 "appimage"
               elsif extension_match
                 warnings << "File name looks like an AppImage, but the ELF header was not found."
                 "appimage"
               elsif deb_valid
                 "deb"
               elsif deb_extension_match
                 warnings << "File name looks like a Debian package, but the archive structure was not recognized."
                 "deb"
               elsif rpm_valid
                 "rpm"
               elsif rpm_extension_match
                 warnings << "File name looks like an RPM package, but the RPM header was not recognized."
                 "rpm"
               elsif flatpakref_valid
                 "flatpakref"
               elsif flatpakref_extension_match
                 warnings << "File name looks like a Flatpak reference, but the file structure was not recognized."
                 "flatpakref"
               elsif archive_valid
                 archive_package.format
               elsif archive_extension_match
                 warnings << "File name looks like a tar archive, but the archive could not be read."
                 archive_package&.format || "tar.gz"
               elsif elf
                 warnings << "File is an ELF executable, but does not use the .AppImage extension."
                 "elf"
               else
                 "unknown"
               end

      confidence = if extension_match && elf
                     "high"
                   elsif deb_valid
                     "high"
                   elsif archive_valid
                     "high"
                   elsif rpm_valid
                     "high"
                   elsif flatpakref_valid
                     "high"
                   elsif extension_match || deb_extension_match || rpm_extension_match || flatpakref_extension_match || archive_extension_match || elf
                     "medium"
                   else
                     "low"
                   end

      risks << "Installing may execute the AppImage runtime to extract desktop metadata." if format == "appimage"
      if format == "deb"
        deb_metadata = deb_valid ? deb_metadata(deb_package) : {}
        metadata.merge!(deb_metadata)
        warnings.concat(deb_warnings(deb_metadata))
        risks.concat(deb_risks(deb_metadata))
      end
      if archive_format?(format)
        archive_metadata = archive_valid ? archive_metadata(archive_package) : {}
        metadata.merge!(archive_metadata)
        warnings.concat(archive_warnings(archive_metadata))
        risks.concat(archive_risks(archive_metadata))
      end
      if format == "rpm"
        rpm_metadata = rpm_valid ? rpm_metadata(rpm_package) : {}
        metadata.merge!(rpm_metadata)
        warnings.concat(rpm_warnings(rpm_metadata))
        risks.concat(rpm_risks(rpm_metadata))
      end
      if format == "flatpakref"
        flatpakref_metadata = flatpakref_valid ? flatpakref_metadata(flatpak_ref) : {}
        metadata.merge!(flatpakref_metadata)
        warnings.concat(flatpakref_warnings(flatpakref_metadata))
        risks.concat(flatpakref_risks(flatpakref_metadata))
      end
      risks << "This format does not have an installer backend yet." unless %w[appimage deb rpm flatpakref tar.gz tar.xz tar.zst].include?(format)

      Inspection.new(
        input: path,
        format:,
        confidence:,
        display_name:,
        sha256: checksum ? Util.sha256(path) : nil,
        size: File.size(path),
        executable: File.executable?(path),
        metadata: {
          "extension_appimage" => extension_match,
          "extension_deb" => deb_extension_match,
          "extension_rpm" => rpm_extension_match,
          "extension_flatpakref" => flatpakref_extension_match,
          "extension_archive" => archive_extension_match,
          "elf" => elf
        }.merge(metadata),
        warnings:,
        risks:
      )
    end

    def elf?(path)
      File.open(path, "rb") { |file| file.read(4) == ELF_MAGIC }
    rescue SystemCallError
      false
    end

    def format_from_name(name)
      return "appimage" if name.match?(APPIMAGE_EXT)
      return "deb" if name.match?(DEB_EXT)
      return "rpm" if name.match?(RPM_EXT)
      return "flatpakref" if name.match?(FLATPAKREF_EXT)
      return ArchivePackage.new(name).format if name.match?(ARCHIVE_EXT)

      "unknown"
    end

    def archive_format?(format)
      %w[tar.gz tar.xz tar.zst].include?(format)
    end

    def deb_metadata(package)
      fields = package.control_fields
      {
        "debian_binary" => package.debian_binary,
        "ar_members" => package.ar_members,
        "control_archive" => package.control_archive_name,
        "data_archive" => package.data_archive_name,
        "package" => fields["Package"],
        "version" => fields["Version"],
        "architecture" => fields["Architecture"],
        "maintainer" => fields["Maintainer"],
        "description" => fields["Description"],
        "depends" => fields["Depends"],
        "homepage" => fields["Homepage"],
        "maintainer_scripts" => package.maintainer_scripts,
        "desktop_entries" => package.desktop_entries,
        "primary_desktop_entry" => package.primary_desktop_entry,
        "icon_count" => package.icon_entries.size,
        "executable_candidates" => package.executable_entries.first(12),
        "data_entry_count" => package.data_members.size
      }
    rescue DebPackage::FormatError => e
      { "deb_error" => e.message }
    end

    def deb_warnings(metadata)
      warnings = [
        "This is a Debian package. Debian packages are usually designed for Debian-based distributions and may not behave correctly on every Linux distribution."
      ]
      scripts = metadata.fetch("maintainer_scripts", [])
      warnings << "Maintainer scripts are present and will not be executed in Depot portable mode: #{scripts.join(", ")}." unless scripts.empty?
      dependencies = dependency_names(metadata["depends"])
      unless dependencies.empty?
        warnings << "Dependencies are declared and are not automatically installed in portable mode: #{dependency_summary(dependencies)}."
      end
      warnings
    end

    def deb_risks(metadata)
      risks = [
        "Depot installs Debian packages by portable extraction, not by registering them with apt or dpkg.",
        "Some Debian packages assume system paths, services, users, or libraries that may not exist outside Debian-family systems."
      ]
      risks << "No desktop launcher was found; Depot may not be able to integrate this package cleanly." unless metadata["primary_desktop_entry"]
      risks
    end

    def dependency_names(depends)
      depends.to_s.split(",").map do |dependency|
        dependency.split("|").first.to_s.strip.sub(/\s*\(.+\)\z/, "")
      end.reject(&:empty?).uniq
    end

    def dependency_summary(dependencies)
      shown = dependencies.first(6).join(", ")
      extra = dependencies.length - 6
      extra.positive? ? "#{dependencies.length} dependencies, including #{shown}, and #{extra} more" : shown
    end

    def archive_metadata(package)
      {
        "archive_format" => package.format,
        "archive_root" => package.common_root,
        "desktop_entries" => package.desktop_entries,
        "primary_desktop_entry" => package.primary_desktop_entry,
        "icon_count" => package.image_entries.size,
        "executable_candidates" => package.executable_candidates,
        "script_entries" => package.script_entries,
        "source_markers" => package.source_markers,
        "data_entry_count" => package.members.size
      }
    rescue ArchivePackage::FormatError => e
      { "archive_error" => e.message }
    end

    def archive_warnings(metadata)
      warnings = ["This archive is not a formal Linux package. Depot will infer the app layout and will not run installer scripts."]
      scripts = metadata.fetch("script_entries", [])
      markers = metadata.fetch("source_markers", [])
      warnings << "Installer-like scripts were found and will not be executed: #{scripts.first(6).join(", ")}." unless scripts.empty?
      warnings << "Source/build markers were found: #{markers.join(", ")}." unless markers.empty?
      warnings
    end

    def archive_risks(metadata)
      risks = ["Tar archives can contain arbitrary layouts, so Depot uses portable extraction and desktop inference."]
      risks << "No desktop launcher was found; Depot will generate one if it can identify an executable." unless metadata["primary_desktop_entry"]
      risks << "No executable candidate was found; install may not be launchable." if metadata.fetch("executable_candidates", []).empty?
      risks
    end

    def rpm_metadata(package)
      fields = package.package_fields
      {
        "package" => fields["Name"],
        "version" => fields["Version"],
        "release" => fields["Release"],
        "architecture" => fields["Architecture"],
        "summary" => fields["Summary"],
        "description" => fields["Description"],
        "license" => fields["License"],
        "url" => fields["URL"],
        "payload_format" => fields["PayloadFormat"],
        "payload_compressor" => fields["PayloadCompressor"],
        "requires" => package.requires,
        "scriptlets" => package.scriptlets,
        "desktop_entries" => package.desktop_entries,
        "primary_desktop_entry" => package.primary_desktop_entry,
        "icon_count" => package.icon_entries.size,
        "executable_candidates" => package.executable_candidates,
        "data_entry_count" => package.file_entries.size
      }
    rescue RpmPackage::FormatError => e
      { "rpm_error" => e.message }
    end

    def rpm_warnings(metadata)
      warnings = [
        "This is an RPM package. RPM packages are usually designed for RPM-based distributions and may not behave correctly on every Linux distribution."
      ]
      scriptlets = metadata.fetch("scriptlets", [])
      warnings << "RPM scriptlets are present and will not be executed in Depot portable mode: #{scriptlets.join(", ")}." unless scriptlets.empty?
      requirements = rpm_requirement_names(metadata["requires"])
      unless requirements.empty?
        warnings << "RPM requirements are declared and are not automatically installed in portable mode: #{dependency_summary(requirements)}."
      end
      warnings
    end

    def rpm_risks(metadata)
      risks = [
        "Depot installs RPM packages by portable extraction, not by registering them with rpm, dnf, or zypper.",
        "Some RPM packages assume system paths, services, users, or libraries that may not exist outside RPM-family systems."
      ]
      risks << "No desktop launcher was found; Depot may not be able to integrate this package cleanly." unless metadata["primary_desktop_entry"]
      risks
    end

    def rpm_requirement_names(requires)
      Array(requires).map do |requirement|
        requirement.to_s.sub(/\s*\(.+\)\z/, "")
      end.reject { |name| name.empty? || name.start_with?("rpmlib(") }.uniq
    end

    def flatpakref_metadata(ref)
      {
        "name" => ref.name,
        "title" => ref.title,
        "branch" => ref.branch,
        "url" => ref.url,
        "suggest_remote_name" => ref.remote_name,
        "is_runtime" => ref.runtime?,
        "runtime_repo" => ref.runtime_repo,
        "gpg_key_present" => ref.gpg_key?,
        "fields" => ref.fields
      }
    rescue FlatpakRef::FormatError => e
      { "flatpakref_error" => e.message }
    end

    def flatpakref_warnings(metadata)
      warnings = ["This Flatpak reference will be installed through the system Flatpak tool into the user Flatpak installation."]
      warnings << "This ref points to a runtime; Depot currently focuses on Flatpak application refs." if metadata["is_runtime"]
      warnings << "No GPG key is embedded in this ref." unless metadata["gpg_key_present"]
      warnings
    end

    def flatpakref_risks(metadata)
      risks = [
        "Flatpak may download the application, runtime dependencies, and remote metadata from #{metadata["url"] || "the configured remote"}.",
        "Flatpak manages sandboxing, updates, exported launchers, and uninstall behavior for this app."
      ]
      risks << "A runtime repo may be added or used: #{metadata["runtime_repo"]}." if metadata["runtime_repo"]
      risks
    end

    def parse_uri(value)
      uri = URI.parse(value)
      uri if uri.scheme && uri.host
    rescue URI::InvalidURIError
      nil
    end
  end
end
