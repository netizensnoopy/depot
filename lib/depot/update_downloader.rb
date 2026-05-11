# frozen_string_literal: true

require "digest"
require "fileutils"
require "net/http"
require "tmpdir"
require "uri"
require_relative "result"
require_relative "version"

module Depot
  module UpdateDownloader
    MAX_DOWNLOAD_BYTES = 2 * 1024 * 1024 * 1024
    MAX_REDIRECTS = 5
    OPEN_TIMEOUT_SECONDS = 15
    READ_TIMEOUT_SECONDS = 60
    KNOWN_SUFFIXES = [
      ".flatpakref",
      ".AppImage",
      ".appimage",
      ".tar.gz",
      ".tgz",
      ".tar.xz",
      ".txz",
      ".tar.zst",
      ".tzst",
      ".deb",
      ".rpm"
    ].freeze

    module_function

    def download(url, max_bytes: MAX_DOWNLOAD_BYTES, redirects: MAX_REDIRECTS)
      return Result.err("Update downloader requires a block.") unless block_given?

      uri = parse_https_url(url)
      return uri unless uri.ok?

      Dir.mktmpdir("depot-update-") do |dir|
        path = File.join(dir, "package#{suffix_for(uri.value.path)}")
        result = download_to(uri.value, path, max_bytes:, redirects:)
        return result unless result.ok?

        yield path, result.value
      end
    rescue SystemCallError => e
      Result.err("Could not download update: #{e.message}")
    end

    def https_url?(url)
      parse_https_url(url).ok?
    end

    def parse_https_url(url)
      uri = URI.parse(url.to_s)
      return Result.err("Update URL must use https://.") unless uri.is_a?(URI::HTTPS)
      return Result.err("Update URL is missing a host.") if uri.host.to_s.empty?

      Result.ok(uri)
    rescue URI::InvalidURIError
      Result.err("Update URL must be a valid https:// URL.")
    end

    def download_to(uri, path, max_bytes:, redirects:)
      return Result.err("Update download redirected too many times.") if redirects.negative?

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = OPEN_TIMEOUT_SECONDS
      http.read_timeout = READ_TIMEOUT_SECONDS

      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "Depot/#{Depot::VERSION}"
      result = nil
      http.request(request) do |response|
        result = case response
                 when Net::HTTPSuccess
                   stream_response(uri, response, path, max_bytes)
                 when Net::HTTPRedirection
                   follow_redirect(uri, response, path, max_bytes:, redirects:)
                 else
                   Result.err("Update download failed: HTTP #{response.code}")
                 end
      end
      result || Result.err("Update download failed before Depot received a response.")
    rescue Timeout::Error, IOError, SystemCallError => e
      Result.err("Update download failed: #{e.message}")
    end

    def follow_redirect(uri, response, path, max_bytes:, redirects:)
      location = response["location"].to_s
      return Result.err("Update download redirected without a location.") if location.empty?

      redirected = URI.join(uri, location)
      return Result.err("Update redirects must stay on https://.") unless redirected.is_a?(URI::HTTPS)

      download_to(redirected, path, max_bytes:, redirects: redirects - 1)
    rescue URI::InvalidURIError
      Result.err("Update download redirected to an invalid URL.")
    end

    def stream_response(uri, response, path, max_bytes)
      content_length = response["content-length"].to_i
      if content_length.positive? && content_length > max_bytes
        return Result.err("Update is too large to download safely (#{content_length} bytes).")
      end

      digest = Digest::SHA256.new
      bytes = 0
      File.open(path, "wb") do |file|
        response.read_body do |chunk|
          bytes += chunk.bytesize
          return Result.err("Update exceeded Depot's #{max_bytes} byte safety limit.") if bytes > max_bytes

          digest.update(chunk)
          file.write(chunk)
        end
      end

      return Result.err("Update download was empty.") if bytes.zero?

      Result.ok(
        {
          "url" => uri.to_s,
          "size" => bytes,
          "sha256" => digest.hexdigest
        }
      )
    end

    def suffix_for(path)
      basename = File.basename(path.to_s)
      KNOWN_SUFFIXES.find { |suffix| basename.end_with?(suffix) } || File.extname(basename)
    end
  end
end
