# frozen_string_literal: true

require "uri"

module Depot
  module SourceResolver
    module_function

    def resolve(source)
      source = source.to_s
      return source if !source.empty? && File.exist?(source)

      fixture_match(source)
    end

    def url?(source)
      uri = URI.parse(source.to_s)
      uri.absolute? && !uri.scheme.to_s.empty?
    rescue URI::InvalidURIError
      false
    end

    def https_url?(source)
      uri = URI.parse(source.to_s)
      uri.is_a?(URI::HTTPS)
    rescue URI::InvalidURIError
      false
    end

    def fixture_match(source)
      return nil if source.empty?

      Dir[File.expand_path("../../fixtures/**/#{File.basename(source)}", __dir__)].first
    end
  end
end
