# frozen_string_literal: true

module Depot
  Result = Struct.new(:ok?, :value, :warnings, :error, keyword_init: true) do
    def self.ok(value = nil, warnings: [])
      new(ok?: true, value:, warnings:, error: nil)
    end

    def self.err(error, warnings: [])
      new(ok?: false, value: nil, warnings:, error:)
    end
  end
end
