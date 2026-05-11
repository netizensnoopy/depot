# frozen_string_literal: true

module Depot
  Inspection = Struct.new(
    :input,
    :format,
    :confidence,
    :display_name,
    :sha256,
    :size,
    :executable,
    :metadata,
    :warnings,
    :risks,
    keyword_init: true
  ) do
    def appimage?
      format == "appimage"
    end

    def deb?
      format == "deb"
    end

    def archive?
      %w[tar.gz tar.xz tar.zst].include?(format)
    end

    def rpm?
      format == "rpm"
    end

    def flatpakref?
      format == "flatpakref"
    end

    def to_h
      {
        "input" => input,
        "format" => format,
        "confidence" => confidence,
        "display_name" => display_name,
        "sha256" => sha256,
        "size" => size,
        "executable" => executable,
        "metadata" => metadata,
        "warnings" => warnings,
        "risks" => risks
      }
    end
  end
end
