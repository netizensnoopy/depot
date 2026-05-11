# frozen_string_literal: true

module Depot
  module GUI
    class DropPanel < RubyQt6::Bando::QFrame
      def initialize(&on_file)
        super()
        @on_file = on_file
        set_accept_drops(true)
        set_object_name("depotDropPanel")
        set_frame_shape(QFrame::StyledPanel)
        set_minimum_height(280)

        @label = QLabel.new("Drop software here")
        @label.set_alignment(Qt::AlignCenter)
        @label.set_word_wrap(true)
        @label.set_object_name("depotDropTitle")
        @label.set_attribute(Qt::WA_TransparentForMouseEvents)
        @hint = QLabel.new("or choose a package with the file picker")
        @hint.set_alignment(Qt::AlignCenter)
        @hint.set_object_name("depotDropHint")
        @hint.set_attribute(Qt::WA_TransparentForMouseEvents)

        layout = QVBoxLayout.new
        layout.add_stretch
        layout.add_widget(@label)
        layout.add_widget(@hint)
        layout.add_stretch
        set_layout(layout)
      end

      def drag_enter_event(event)
        if file_from_event(event)
          @hint.set_text("Release to inspect this software")
          event.accept_proposed_action
        else
          event.ignore
        end
      end

      def drag_leave_event(event)
        @hint.set_text("or choose a package with the file picker")
      end

      def drag_move_event(event)
        if file_from_event(event)
          event.accept_proposed_action
        else
          event.ignore
        end
      end

      def drop_event(event)
        path = file_from_event(event)
        return event.ignore unless path

        @hint.set_text("or choose a package with the file picker")
        @on_file.call(path)
        event.accept_proposed_action
      end

      private

      def file_from_event(event)
        mime = event.mime_data
        return nil unless mime.respond_to?(:has_urls) && mime.has_urls

        url = mime.urls.first
        return nil unless url

        local = url.to_local_file.to_s
        return nil if local.empty?

        local
      rescue StandardError
        nil
      end
    end
  end
end
