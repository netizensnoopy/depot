# frozen_string_literal: true

require "json"
require "fileutils"
require_relative "paths"

module Depot
  class ManifestStore
    attr_reader :dir

    def initialize(dir = Paths.manifests_dir)
      @dir = dir
    end

    def all
      Dir.glob(File.join(dir, "*.json")).sort.filter_map { |path| read_file(path) }
    end

    def ids
      all.map { |manifest| manifest.fetch("app_id") }
    end

    def find(app_id)
      path = manifest_path(app_id)
      return nil unless File.exist?(path)

      read_file(path)
    end

    def write(manifest)
      FileUtils.mkdir_p(dir)
      path = manifest_path(manifest.fetch("app_id"))
      File.write(path, JSON.pretty_generate(manifest) + "\n")
      path
    end

    def delete(app_id)
      FileUtils.rm_f(manifest_path(app_id))
    end

    def manifest_path(app_id)
      File.join(dir, "#{app_id}.json")
    end

    private

    def read_file(path)
      JSON.parse(File.read(path))
    rescue JSON::ParserError
      nil
    end
  end
end
