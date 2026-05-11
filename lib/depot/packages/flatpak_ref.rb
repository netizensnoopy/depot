# frozen_string_literal: true

module Depot
  class FlatpakRef
    GROUP = "Flatpak Ref"
    BOOLEAN_KEYS = %w[IsRuntime].freeze

    attr_reader :path

    def initialize(path)
      @path = path
    end

    def valid?
      fields.fetch("Name", "").to_s != "" && fields.fetch("Url", "").to_s != ""
    rescue FormatError
      false
    end

    def fields
      @fields ||= parse
    end

    def name
      fields["Name"]
    end

    def branch
      fields["Branch"] || "master"
    end

    def title
      fields["Title"]
    end

    def display_name
      title.to_s.sub(/\s+from\s+\S+\z/i, "").then { |value| value.empty? ? name : value }
    end

    def runtime?
      fields["IsRuntime"] == true
    end

    def remote_name
      fields["SuggestRemoteName"]
    end

    def url
      fields["Url"]
    end

    def runtime_repo
      fields["RuntimeRepo"]
    end

    def gpg_key?
      fields["GPGKey"].to_s.strip != ""
    end

    class FormatError < StandardError; end

    private

    def parse
      current_group = nil
      parsed = {}
      File.foreach(path, chomp: true) do |line|
        stripped = line.strip
        next if stripped.empty? || stripped.start_with?("#", ";")

        if stripped.start_with?("[") && stripped.end_with?("]")
          current_group = stripped[1...-1]
          next
        end
        next unless current_group == GROUP

        key, value = stripped.split("=", 2)
        next unless key && value

        parsed[key] = BOOLEAN_KEYS.include?(key) ? value.downcase == "true" : value
      end

      raise FormatError, "Missing [#{GROUP}] group" if parsed.empty?

      parsed
    rescue SystemCallError => e
      raise FormatError, e.message
    end
  end
end
