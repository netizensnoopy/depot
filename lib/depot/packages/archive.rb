# frozen_string_literal: true

require "fileutils"
require "open3"

module Depot
  class ArchivePackage
    DESKTOP_PATH = %r{\A(?:\./)?(.+/)?[^/]+\.desktop\z}
    HICOLOR_ICON_PATH = %r{/icons/hicolor/([^/]+)/apps/([^/]+)\.(png|svg|xpm)\z}i
    IMAGE_EXT = /\.(png|svg|xpm)\z/i
    SCRIPT_EXT = /\.(sh|bash|run|pl|py|rb)\z/i
    SOURCE_MARKERS = %w[configure Makefile CMakeLists.txt meson.build setup.py package.json Cargo.toml go.mod].freeze

    attr_reader :path

    def initialize(path)
      @path = path
    end

    def valid?
      tar_name? && !members.empty?
    rescue FormatError
      false
    end

    def format
      case File.basename(path)
      when /\.t(?:ar\.)?gz\z/i, /\.tgz\z/i then "tar.gz"
      when /\.tar\.xz\z/i, /\.txz\z/i then "tar.xz"
      when /\.tar\.zst\z/i, /\.tzst\z/i then "tar.zst"
      else "archive"
      end
    end

    def display_name
      root = common_root
      return titleize(root) if root && root != "."

      titleize(File.basename(path).sub(/\.(tar\.gz|tgz|tar\.xz|txz|tar\.zst|tzst)\z/i, ""))
    end

    def members
      @members ||= list_archive
    end

    def clean_members
      members.map { |entry| clean_entry(entry) }
    end

    def desktop_entries
      clean_members.select { |entry| entry.end_with?(".desktop") }
    end

    def primary_desktop_entry
      desktop_entries.min_by { |entry| desktop_score(entry) }
    end

    def image_entries
      clean_members.select { |entry| entry.match?(IMAGE_EXT) }
    end

    def icon_entries
      clean_members.select { |entry| entry.match?(HICOLOR_ICON_PATH) }
    end

    def executable_candidates
      clean_members.reject { |entry| entry.end_with?("/") }
                   .select { |entry| executable_name?(entry) }
                   .first(24)
    end

    def script_entries
      clean_members.reject { |entry| entry.end_with?("/") }
                   .select { |entry| File.basename(entry).match?(SCRIPT_EXT) || File.basename(entry).match?(/\Ainstall/i) }
                   .first(24)
    end

    def source_markers
      clean_members.map { |entry| File.basename(entry) }
                   .select { |name| SOURCE_MARKERS.include?(name) }
                   .uniq
    end

    def common_root
      roots = clean_members.reject(&:empty?).map { |entry| entry.split("/", 2).first }.uniq
      roots.length == 1 ? roots.first : nil
    end

    def read_entry(entry)
      wanted = clean_entry(entry)
      candidate = members.find { |member| clean_entry(member) == wanted }
      raise FormatError, "Could not find #{entry} in archive" unless candidate

      stdout, stderr, status = Open3.capture3("tar", *tar_options, "-xOf", path, candidate)
      raise FormatError, "Could not read #{entry}: #{stderr.empty? ? stdout : stderr}" unless status.success?

      stdout
    end

    def extract_to(destination)
      FileUtils.mkdir_p(destination)
      assert_safe_entries!
      stdout, stderr, status = Open3.capture3("tar", *tar_options, "-xf", path, "-C", destination)
      raise FormatError, "Could not extract archive: #{stderr.empty? ? stdout : stderr}" unless status.success?
    end

    class FormatError < StandardError; end

    private

    def tar_name?
      File.basename(path).match?(/\.(tar\.gz|tgz|tar\.xz|txz|tar\.zst|tzst)\z/i)
    end

    def list_archive
      stdout, stderr, status = Open3.capture3("tar", *tar_options, "-tf", path)
      raise FormatError, "Could not list archive: #{stderr.empty? ? stdout : stderr}" unless status.success?

      stdout.lines.map(&:chomp).reject(&:empty?)
    end

    def tar_options
      case File.basename(path)
      when /\.(tar\.gz|tgz)\z/i then ["-z"]
      when /\.(tar\.xz|txz)\z/i then ["-J"]
      when /\.(tar\.zst|tzst)\z/i then ["--zstd"]
      else []
      end
    end

    def assert_safe_entries!
      unsafe = members.find do |entry|
        clean = clean_entry(entry)
        entry.start_with?("/") || clean.split("/").include?("..")
      end
      raise FormatError, "Unsafe path in archive: #{unsafe}" if unsafe
    end

    def clean_entry(entry)
      entry.to_s.sub(%r{\A\./}, "")
    end

    def executable_name?(entry)
      base = File.basename(entry)
      return false if SOURCE_MARKERS.include?(base)
      return false if base.match?(/\A(install|setup|configure)\b/i)
      return true if base == "AppRun"
      return true if entry.include?("/bin/") && !base.include?(".")
      return true if base.match?(SCRIPT_EXT)

      !base.include?(".") && !entry.include?("/share/") && !entry.include?("/doc/")
    end

    def desktop_score(entry)
      metadata = parse_desktop_entry(read_entry(entry))
      [
        metadata["NoDisplay"].to_s.downcase == "true" ? 1 : 0,
        metadata["Hidden"].to_s.downcase == "true" ? 1 : 0,
        metadata["Type"] == "Application" ? 0 : 1,
        clean_entry(entry).match?(%r{/share/applications/[^/]+\.desktop\z}) ? 0 : 1,
        metadata["Name"].to_s.downcase.include?("url handler") ? 1 : 0,
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

    def titleize(value)
      value.to_s.gsub(/[_-]+/, " ").split.map(&:capitalize).join(" ")
    end
  end
end
