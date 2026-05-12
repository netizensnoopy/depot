# frozen_string_literal: true

require_relative "result"
require_relative "sandbox"
require_relative "settings"

module Depot
  module Launcher
    module_function

    def launch(manifest, settings: Settings.new.load, spawn: Process.method(:spawn), detach: Process.method(:detach))
      executable = Sandbox.launch_path(manifest, settings:)
      return Result.err("This app does not have a launchable executable recorded.") if executable.to_s.strip.empty?

      pid = spawn.call(executable, pgroup: true)
      detach.call(pid) if detach
      Result.ok(pid)
    rescue SystemCallError, ArgumentError => e
      Result.err("Could not launch app: #{e.message}")
    end
  end
end
