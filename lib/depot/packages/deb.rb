# frozen_string_literal: true

require "fileutils"
require "open3"
require "shellwords"
require "tempfile"

module Depot
  class DebPackage
    SCRIPT_NAMES = %w[preinst postinst prerm postrm config].freeze
    DESKTOP_PATH = %r{\A(?:\./)?usr/share/applications/[^/]+\.desktop\z}
    ICON_PATH = %r{/icons/hicolor/([^/]+)/apps/([^/]+)\.(png|svg|xpm)\z}i

    attr_reader :path

    def initialize(path)
      @path = path
    end

    def valid?
      debian_binary && control_archive_name && data_archive_name
    rescue FormatError
      false
    end

    def debian_binary
      member("debian-binary")&.strip
    end

    def control_fields
      @control_fields ||= parse_control(read_control_file("control").to_s)
    end

    def control_members
      @control_members ||= list_tar(control_archive_name)
    end

    def data_members
      @data_members ||= list_tar(data_archive_name)
    end

    def maintainer_scripts
      control_members.map { |entry| clean_entry(entry) }
                     .select { |entry| SCRIPT_NAMES.include?(File.basename(entry)) }
                     .uniq
    end

    def desktop_entries
      data_members.map { |entry| clean_entry(entry) }
                  .select { |entry| entry.end_with?(".desktop") }
    end

    def primary_desktop_entry
      desktop_entries.min_by { |entry| desktop_score(entry) }
    end

    def icon_entries
      data_members.map { |entry| clean_entry(entry) }
                  .select { |entry| entry.match?(ICON_PATH) }
    end

    def image_entries
      data_members.map { |entry| clean_entry(entry) }
                  .select { |entry| entry.match?(/\.(png|svg|xpm)\z/i) }
    end

    def executable_entries
      data_members.map { |entry| clean_entry(entry) }
                  .select { |entry| entry.start_with?("usr/bin/", "usr/local/bin/", "opt/") }
                  .reject { |entry| entry.end_with?("/") }
    end

    def control_archive_name
      @control_archive_name ||= archive_name("control.tar")
    end

    def data_archive_name
      @data_archive_name ||= archive_name("data.tar")
    end

    def ar_members
      @ar_members ||= parse_ar.keys
    end

    def read_data_entry(entry)
      read_tar_entry(data_archive_name, entry)
    end

    def extract_data_to(destination)
      FileUtils.mkdir_p(destination)
      assert_safe_entries!(data_members)
      with_member_file(data_archive_name) do |archive|
        stdout, stderr, status = Open3.capture3(
          "tar",
          *tar_options(data_archive_name),
          "-xf",
          archive,
          "-C",
          destination
        )
        raise FormatError, "Could not extract data archive: #{stderr.empty? ? stdout : stderr}" unless status.success?
      end
    end

    private

    class FormatError < StandardError; end

    def member(name)
      parse_ar[normalize_ar_name(name)]
    end

    def archive_name(prefix)
      ar_members.find { |name| name.start_with?(prefix) }
    end

    def read_control_file(name)
      read_tar_entry(control_archive_name, name)
    end

    def read_tar_entry(archive_name, entry)
      wanted = clean_entry(entry)
      candidate = list_tar(archive_name).find { |member| clean_entry(member) == wanted }
      raise FormatError, "Could not find #{entry} in #{archive_name}" unless candidate

      with_member_file(archive_name) do |archive|
        stdout, stderr, status = Open3.capture3(
          "tar",
          *tar_options(archive_name),
          "-xOf",
          archive,
          candidate
        )
        raise FormatError, "Could not read #{entry}: #{stderr.empty? ? stdout : stderr}" unless status.success?

        stdout
      end
    end

    def list_tar(archive_name)
      with_member_file(archive_name) do |archive|
        stdout, stderr, status = Open3.capture3("tar", *tar_options(archive_name), "-tf", archive)
        raise FormatError, "Could not list #{archive_name}: #{stderr.empty? ? stdout : stderr}" unless status.success?

        stdout.lines.map(&:chomp).reject(&:empty?)
      end
    end

    def with_member_file(name)
      data = member(name)
      raise FormatError, "Missing #{name}" unless data

      file = Tempfile.new(["depot-deb-", File.extname(name)])
      file.binmode
      file.write(data)
      file.close
      yield file.path
    ensure
      file&.unlink
    end

    def tar_options(name)
      case name
      when /\.tar\.xz\z/ then ["-J"]
      when /\.tar\.gz\z/ then ["-z"]
      when /\.tar\.bz2\z/ then ["-j"]
      when /\.tar\.zst\z/ then ["--zstd"]
      else []
      end
    end

    def parse_control(text)
      fields = {}
      current = nil
      text.each_line(chomp: true) do |line|
        if line.start_with?(" ", "\t")
          fields[current] = [fields[current], line.sub(/\A[ \t]/, "")].compact.join("\n") if current
          next
        end

        key, value = line.split(":", 2)
        next unless value

        current = key
        fields[key] = value.strip
      end
      fields
    end

    def assert_safe_entries!(entries)
      unsafe = entries.find do |entry|
        clean = clean_entry(entry)
        entry.start_with?("/") || clean.split("/").include?("..")
      end
      raise FormatError, "Unsafe path in data archive: #{unsafe}" if unsafe
    end

    def clean_entry(entry)
      entry.to_s.sub(%r{\A\./}, "")
    end

    def desktop_score(entry)
      metadata = parse_desktop_entry(read_data_entry(entry))
      [
        metadata["NoDisplay"].to_s.downcase == "true" ? 1 : 0,
        metadata["Hidden"].to_s.downcase == "true" ? 1 : 0,
        metadata["Type"] == "Application" ? 0 : 1,
        clean_entry(entry).match?(DESKTOP_PATH) ? 0 : 1,
        metadata["Name"].to_s.downcase.include?("url handler") ? 1 : 0,
        File.basename(entry).include?("-url-handler") ? 1 : 0,
        clean_entry(entry).length
      ]
    rescue FormatError
      [9, clean_entry(entry).length]
    end

    def parse_desktop_entry(contents)
      metadata = {}
      in_desktop_entry = false
      contents.each_line(chomp: true) do |line|
        if line.start_with?("[")
          in_desktop_entry = line.strip == "[Desktop Entry]"
          next
        end
        next unless in_desktop_entry

        key, value = line.split("=", 2)
        metadata[key] = value if value && !metadata.key?(key)
      end
      metadata
    end

    def parse_ar
      @parse_ar ||= begin
        File.open(path, "rb") do |file|
          raise FormatError, "Not an ar archive" unless file.read(8) == "!<arch>\n"

          members = {}
          until file.eof?
            header = file.read(60)
            break if header.nil? || header.empty?
            raise FormatError, "Truncated ar header" unless header.bytesize == 60
            raise FormatError, "Invalid ar member header" unless header.byteslice(58, 2) == "`\n"

            name = normalize_ar_name(header.byteslice(0, 16))
            size = header.byteslice(48, 10).to_s.strip.to_i
            data = file.read(size)
            raise FormatError, "Truncated ar member #{name}" unless data && data.bytesize == size

            file.read(1) if size.odd?
            members[name] = data
          end
          members
        end
      end
    end

    def normalize_ar_name(name)
      name.to_s.strip.sub(%r{/\z}, "")
    end
  end
end
