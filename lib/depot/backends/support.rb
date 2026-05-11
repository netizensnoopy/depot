# frozen_string_literal: true

require "fileutils"
require "shellwords"
require_relative "../paths"

module Depot
  module Backends
    module Support
      private

      def command_available?(command)
        ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, command)) }
      end

      def refresh_desktop_caches
        if command_available?("gtk-update-icon-cache") && Dir.exist?(Paths.icon_root)
          system("gtk-update-icon-cache", "-f", "-t", Paths.icon_root, out: File::NULL, err: File::NULL)
        end
        if command_available?("update-desktop-database") && Dir.exist?(Paths.desktop_entries_dir)
          system("update-desktop-database", Paths.desktop_entries_dir, out: File::NULL, err: File::NULL)
        end
      end

      def write_shell_launcher(path, command, *args)
        FileUtils.mkdir_p(File.dirname(path))
        escaped = ([command] + args).map { |part| Shellwords.escape(part.to_s) }.join(" ")
        File.write(path, "#!/bin/sh\nexec #{escaped} \"$@\"\n")
        File.chmod(0o755, path)
        path
      end

      def desktop_name_from(contents)
        line = contents.to_s.lines.find { |candidate| candidate.start_with?("Name=") }
        line&.split("=", 2)&.last&.strip
      end
    end
  end
end
