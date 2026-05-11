# frozen_string_literal: true

require "json"
require "fileutils"
require_relative "paths"

module Depot
  class Settings
    DEFAULTS = {
      "warning_verbosity" => "normal",
      "theme" => "system",
      "default_install_location" => "user",
      "sandbox_preference" => "ask",
      "sandbox_profile" => "balanced",
      "sandbox_home_access" => "documents",
      "sandbox_network" => true,
      "desktop_integration" => true,
      "updates_enabled" => true
    }.freeze

    attr_reader :path

    def initialize(path = Paths.settings_path)
      @path = path
    end

    def load
      return DEFAULTS.dup unless File.exist?(path)

      parsed = JSON.parse(File.read(path))
      DEFAULTS.merge(parsed)
    rescue JSON::ParserError
      DEFAULTS.dup
    end

    def save(values)
      FileUtils.mkdir_p(File.dirname(path))
      normalized = DEFAULTS.merge(values.transform_keys(&:to_s))
      File.write(path, JSON.pretty_generate(normalized) + "\n")
      normalized
    end
  end
end
