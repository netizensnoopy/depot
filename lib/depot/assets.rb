# frozen_string_literal: true

module Depot
  module Assets
    module_function

    def logo_path
      File.expand_path("../../fixtures/assets/download.png", __dir__)
    end
  end
end
