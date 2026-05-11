# frozen_string_literal: true

require "digest"

module Depot
  module Util
    module_function

    def sha256(path)
      Digest::SHA256.file(path).hexdigest
    end

    def slug(value)
      base = File.basename(value.to_s, ".*").downcase
      base = base.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
      base.empty? ? "app" : base
    end

    def unique_id(base, taken)
      candidate = base
      index = 2
      while taken.include?(candidate)
        candidate = "#{base}-#{index}"
        index += 1
      end
      candidate
    end

    def desktop_exec_quote(path)
      %("#{path.gsub(/(["\\`$])/, '\\\\\\1')}")
    end
  end
end
