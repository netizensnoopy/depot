# frozen_string_literal: true

require "fileutils"
require "open3"

module Depot
  class RpmPackage
    MAGIC = "\xED\xAB\xEE\xDB".b.freeze
    HEADER_MAGIC = "\x8E\xAD\xE8".b.freeze
    HICOLOR_ICON_PATH = %r{/icons/hicolor/([^/]+)/apps/([^/]+)\.(png|svg|xpm)\z}i
    IMAGE_EXT = /\.(png|svg|xpm)\z/i
    SCRIPT_TAGS = {
      1023 => "preinstall",
      1024 => "postinstall",
      1025 => "preuninstall",
      1026 => "postuninstall",
      1065 => "verify",
      1085 => "triggerinstall",
      1086 => "triggeruninstall",
      1087 => "triggerpostuninstall"
    }.freeze
    TAGS = {
      1000 => "Name",
      1001 => "Version",
      1002 => "Release",
      1004 => "Summary",
      1005 => "Description",
      1014 => "License",
      1015 => "Packager",
      1020 => "URL",
      1021 => "OS",
      1022 => "Architecture",
      1049 => "Requires",
      1116 => "DirIndexes",
      1117 => "BaseNames",
      1118 => "DirNames",
      1124 => "PayloadFormat",
      1125 => "PayloadCompressor",
      1126 => "PayloadFlags"
    }.merge(SCRIPT_TAGS.transform_values { |name| "Script:#{name}" }).freeze

    attr_reader :path

    def initialize(path)
      @path = path
    end

    def valid?
      rpm_magic? && header_fields.any?
    rescue FormatError
      false
    end

    def header_fields
      @header_fields ||= parse_main_header
    end

    def package_fields
      fields = header_fields
      {
        "Name" => fields["Name"],
        "Version" => fields["Version"],
        "Release" => fields["Release"],
        "Architecture" => fields["Architecture"],
        "Summary" => fields["Summary"],
        "Description" => fields["Description"],
        "License" => fields["License"],
        "Packager" => fields["Packager"],
        "URL" => fields["URL"],
        "PayloadFormat" => fields["PayloadFormat"],
        "PayloadCompressor" => fields["PayloadCompressor"],
        "PayloadFlags" => fields["PayloadFlags"]
      }.compact
    end

    def display_name
      header_fields["Name"] || File.basename(path, ".rpm")
    end

    def version_label
      [header_fields["Version"], header_fields["Release"]].compact.join("-")
    end

    def requires
      Array(header_fields["Requires"]).reject { |name| name.start_with?("rpmlib(") }.uniq
    end

    def scriptlets
      header_fields.filter_map do |key, value|
        next unless key.start_with?("Script:") && value.to_s.strip != ""

        key.delete_prefix("Script:")
      end
    end

    def members
      @members ||= list_payload
    end

    def clean_members
      members.map { |entry| clean_entry(entry) }
    end

    def desktop_entries
      payload_entries.select { |entry| entry.end_with?(".desktop") }
    end

    def primary_desktop_entry
      desktop_entries.min_by { |entry| desktop_score(entry) }
    end

    def image_entries
      payload_entries.select { |entry| entry.match?(IMAGE_EXT) }
    end

    def icon_entries
      payload_entries.select { |entry| entry.match?(HICOLOR_ICON_PATH) }
    end

    def executable_candidates
      payload_entries.reject { |entry| entry.end_with?("/") }
                     .select { |entry| executable_name?(entry) }
                     .first(24)
    end

    def file_entries
      entries = header_file_entries
      entries.empty? ? clean_members : entries
    end

    def header_file_entries
      fields = header_fields
      bases = Array(fields["BaseNames"])
      dirs = Array(fields["DirNames"])
      indexes = Array(fields["DirIndexes"])
      return [] if bases.empty? || dirs.empty? || indexes.empty?

      bases.each_with_index.map do |base, index|
        dir = dirs[indexes[index].to_i].to_s
        clean_entry(File.join(dir, base))
      end
    end

    def read_entry(entry)
      wanted = clean_entry(entry)
      candidates = [wanted, "./#{wanted}"].uniq
      candidates.each do |candidate|
        stdout, stderr, status = Open3.capture3("bsdtar", "-xOf", path, candidate)
        return stdout if status.success?

        @last_read_error = stderr.empty? ? stdout : stderr
      end

      raise FormatError, "Could not read #{entry}: #{@last_read_error}"
    end

    def extract_to(destination)
      FileUtils.mkdir_p(destination)
      assert_bsdtar!
      assert_safe_entries!
      stdout, stderr, status = Open3.capture3("bsdtar", "-xf", path, "-C", destination)
      raise FormatError, "Could not extract RPM payload: #{stderr.empty? ? stdout : stderr}" unless status.success?
    end

    class FormatError < StandardError; end

    private

    def rpm_magic?
      File.open(path, "rb") { |file| file.read(4) == MAGIC }
    rescue SystemCallError
      false
    end

    def parse_main_header
      File.open(path, "rb") do |file|
        file.binmode
        raise FormatError, "Not an RPM file" unless file.read(4) == MAGIC

        file.pos = 96
        read_header(file)
        file.pos += (8 - (file.pos % 8)) % 8
        entries, store = read_header(file)
        fields = {}
        entries.each do |tag, type, offset, count|
          name = TAGS[tag]
          next unless name

          fields[name] = header_value(type, offset, count, store)
        end
        fields
      end
    end

    def read_header(file)
      magic = file.read(3)
      raise FormatError, "Invalid RPM header" unless magic == HEADER_MAGIC

      file.read(1)
      file.read(4)
      index_count = file.read(4).unpack1("N")
      store_size = file.read(4).unpack1("N")
      entries = index_count.times.map { file.read(16).unpack("N4") }
      store = file.read(store_size)
      raise FormatError, "Truncated RPM header store" unless store && store.bytesize == store_size

      [entries, store]
    end

    def header_value(type, offset, count, store)
      case type
      when 2
        store.byteslice(offset, count).unpack("C*")
      when 3
        store.byteslice(offset, count * 2).unpack("n*")
      when 4
        store.byteslice(offset, count * 4).unpack("N*")
      when 5
        store.byteslice(offset, count * 8).unpack("Q>*")
      when 6, 9
        store.byteslice(offset..).split("\0", 2).first.to_s
      when 8
        store.byteslice(offset..).split("\0").first(count)
      when 7
        store.byteslice(offset, count)
      else
        nil
      end
    end

    def list_payload
      assert_bsdtar!
      stdout, stderr, status = Open3.capture3("bsdtar", "-tf", path)
      raise FormatError, "Could not list RPM payload: #{stderr.empty? ? stdout : stderr}" unless status.success?

      stdout.lines.map(&:chomp).reject(&:empty?)
    end

    def assert_bsdtar!
      return if command_available?("bsdtar")

      raise FormatError, "RPM portable extraction requires bsdtar/libarchive."
    end

    def assert_safe_entries!
      unsafe = payload_entries.find do |entry|
        clean = clean_entry(entry)
        entry.start_with?("/") || clean.split("/").include?("..")
      end
      raise FormatError, "Unsafe path in RPM payload: #{unsafe}" if unsafe
    end

    def payload_entries
      entries = header_file_entries
      entries.empty? ? clean_members : entries
    end

    def clean_entry(entry)
      entry.to_s.sub(%r{\A\./}, "").sub(%r{\A/+}, "")
    end

    def executable_name?(entry)
      base = File.basename(entry)
      return true if entry.include?("/bin/") && !base.include?(".")
      return true if entry.start_with?("opt/") && !base.include?(".")

      false
    end

    def desktop_score(entry)
      base = File.basename(entry, ".desktop").downcase
      package_name = display_name.to_s.downcase
      [
        clean_entry(entry).match?(%r{/share/applications/[^/]+\.desktop\z}) ? 0 : 1,
        base.include?("url") || base.include?("handler") ? 1 : 0,
        !package_name.empty? && base.include?(package_name) ? 0 : 1,
        clean_entry(entry).length
      ]
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

    def command_available?(command)
      ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, command)) }
    end
  end
end
