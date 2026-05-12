# frozen_string_literal: true

require "open3"

module Depot
  module GUI
    class InstalledAppsTable < RubyQt6::Bando::QTableWidget
      def initialize(owner)
        super(0, 4)
        @owner = owner
      end

      def context_menu_event(event)
        with_event_errors do
          item = item_at(event.pos)
          return unless item

          set_current_item(item)

          menu = QMenu.new("", self)
          view = menu.add_action("View info")
          rename = menu.add_action("Change title...")
          icon = menu.add_action("Change icon...")
          reset = menu.add_action("Reset properties")
          sandbox = menu.add_action("Sandbox...")
          menu.add_separator
          reinstall = menu.add_action("Reinstall")
          launch = menu.add_action("Launch")
          uninstall = menu.add_action("Uninstall")

          case menu.exec(event.global_pos)&.text.to_s
          when view.text.to_s
            @owner.info_selected
          when rename.text.to_s
            @owner.change_title_selected
          when icon.text.to_s
            @owner.change_icon_selected
          when reset.text.to_s
            @owner.reset_selected
          when sandbox.text.to_s
            @owner.sandbox_selected
          when reinstall.text.to_s
            @owner.reinstall_selected
          when launch.text.to_s
            @owner.launch_selected
          when uninstall.text.to_s
            @owner.uninstall_selected
          end
        end
      end

      private

      def with_event_errors
        yield
      rescue StandardError => e
        @owner.send(:unexpected_error, e)
      end
    end

    class SandboxDialog < RubyQt6::Bando::QDialog
      attr_reader :mode_combo, :profile_combo, :home_combo, :network_check

      def initialize(parent, manifest, settings)
        super(parent)
        @manifest = Sandbox.normalize(manifest, settings)
        sandbox = @manifest.fetch("sandbox", {})

        set_window_title("Sandbox")
        set_modal(true)
        resize(430, 260)

        layout = QVBoxLayout.new
        title = QLabel.new("Sandbox #{manifest.fetch("display_name")}")
        title.set_style_sheet("font-size: 18px; font-weight: 700;")
        layout.add_widget(title)

        note = QLabel.new(description_text)
        note.set_word_wrap(true)
        note.set_object_name("depotInstallSubtitle")
        layout.add_widget(note)

        form = QFormLayout.new
        @mode_combo = QComboBox.new
        %w[inherit enabled disabled].each { |value| @mode_combo.add_item(value) }
        @profile_combo = QComboBox.new
        %w[relaxed balanced strict].each { |value| @profile_combo.add_item(value) }
        @home_combo = QComboBox.new
        %w[isolated documents full].each { |value| @home_combo.add_item(value) }
        @network_check = QCheckBox.new("Allow network access")

        set_combo(@mode_combo, sandbox.fetch("mode", "inherit"))
        set_combo(@profile_combo, sandbox.fetch("profile", "balanced"))
        set_combo(@home_combo, sandbox.fetch("home_access", "documents"))
        @network_check.set_checked(sandbox.fetch("network", true))

        form.add_row(QString.new("Mode"), @mode_combo)
        form.add_row(QString.new("Profile"), @profile_combo)
        form.add_row(QString.new("Home access"), @home_combo)
        form.add_row(QString.new("Network"), @network_check)
        layout.add_layout(form)

        buttons = QHBoxLayout.new
        save = QPushButton.new("Save")
        cancel = QPushButton.new("Cancel")
        save.clicked.connect(self, :accept)
        cancel.clicked.connect(self, :reject)
        buttons.add_stretch
        buttons.add_widget(save)
        buttons.add_widget(cancel)
        layout.add_layout(buttons)
        set_layout(layout)
      end

      def values
        {
          "mode" => @mode_combo.current_text.to_s,
          "profile" => @profile_combo.current_text.to_s,
          "home_access" => @home_combo.current_text.to_s,
          "network" => @network_check.checked?
        }
      end

      private

      def description_text
        return "Flatpak already manages this app's sandbox. Depot shows that state here, but Bubblewrap settings do not apply." if @manifest["backend"] == "flatpak"

        "Bubblewrap runs this app through a generated Depot launcher. If Bubblewrap is missing, Depot falls back to the normal launcher so the app still opens."
      end

      def set_combo(combo, value)
        index = combo.find_text(value)
        combo.set_current_index(index) if index && index >= 0
      end
    end

    class MainWindow < RubyQt6::Bando::QMainWindow
      q_object do
        slot "browse_file()"
        slot "inspect_current()"
        slot "install_current()"
        slot "refresh_updates()"
        slot "set_update_source_selected()"
        slot "update_selected()"
        slot "update_all()"
        slot "refresh_installed()"
        slot "launch_selected()"
        slot "info_selected()"
        slot "change_title_selected()"
        slot "change_icon_selected()"
        slot "reset_selected()"
        slot "sandbox_selected()"
        slot "reinstall_selected()"
        slot "uninstall_selected()"
        slot "save_settings()"
        slot "change_page(int)"
      end

      def initialize
        super()
        @store = ManifestStore.new
        @customizer = AppCustomizer.new(store: @store)
        @settings = Settings.new
        @current_path = nil
        @current_inspection = nil

        set_window_title("Depot")
        resize(980, 660)
        set_window_icon(QIcon.new(Assets.logo_path)) if File.exist?(Assets.logo_path)

        build_ui
        load_settings_controls
        apply_theme(@settings.load.fetch("theme", "system"))
        refresh_installed
      end

      def browse_file
        file = QFileDialog.get_open_file_name(
          self,
          "Choose Software",
          Dir.home,
          "Software packages (*.AppImage *.appimage *.deb *.rpm *.flatpakref *.tar.gz *.tgz *.tar.xz *.txz *.tar.zst *.tzst *.zip);;All files (*)"
        )
        load_input(file) if file && !file.empty?
      end

      def inspect_current
        return warn_dialog("Choose software first.") unless @current_path

        result = Inspector.inspect(@current_path, checksum: false)
        unless result.ok?
          @current_inspection = nil
          @detected_label.set_text("Could not inspect this file")
          @detected_label.set_visible(true)
          @summary.set_plain_text(result.error)
          @install_button.set_enabled(false)
          return
        end

        @current_inspection = result.value
        @detected_label.set_text(detected_summary(@current_inspection))
        @detected_label.set_visible(true)
        @summary.set_plain_text(summary_for(@current_inspection))
        @install_button.set_enabled(installable_inspection?(@current_inspection))
      end

      def install_current
        return warn_dialog("Choose software first.") unless @current_path

        inspect_current unless @current_inspection
        return warn_dialog("No installer backend is available for this format yet.") unless installable_inspection?(@current_inspection)

        answer = QMessageBox.question(
          self,
          "Install Software",
          install_prompt(@current_inspection),
          QMessageBox::Yes | QMessageBox::No
        )
        return unless answer == QMessageBox::Yes

        result = with_install_progress("Installing #{install_progress_name(@current_inspection)}...\n\nThis may take a while.") do
          Installer.install(@current_path, settings: @settings.load)
        end
        if result.ok?
          manifest = result.value
          QMessageBox.information(self, "Installed", "Installed #{manifest.fetch("display_name")} as #{manifest.fetch("app_id")}.")
          @current_path = nil
          @current_inspection = nil
          @path_edit.set_text("")
          @detected_label.set_text("")
          @detected_label.set_visible(false)
          @summary.set_plain_text("")
          @install_button.set_enabled(false)
          refresh_installed
          @sidebar.set_current_row(1)
        else
          warn_dialog(result.error)
        end
      end

      def refresh_installed
        @apps_table.set_row_count(0)
        @store.all.each_with_index do |manifest, row|
          @apps_table.insert_row(row)
          @apps_table.set_item(row, 0, QTableWidgetItem.new(manifest.fetch("app_id")))
          @apps_table.set_item(row, 1, QTableWidgetItem.new(manifest.fetch("display_name")))
          @apps_table.set_item(row, 2, QTableWidgetItem.new(manifest.fetch("backend")))
          @apps_table.set_item(row, 3, QTableWidgetItem.new(manifest.fetch("installed_at", "")))
        end
        @apps_table.resize_columns_to_contents
      end

      def launch_selected
        manifest = selected_manifest
        return warn_dialog("Select an installed app first.") unless manifest

        result = Launcher.launch(manifest, settings: @settings.load)
        warn_dialog(result.error) unless result.ok?
      end

      def info_selected
        manifest = selected_manifest
        return warn_dialog("Select an installed app first.") unless manifest

        custom = manifest.fetch("customizations", {})
        custom_icon = manifest["custom_icon"]
        QMessageBox.information(
          self,
          manifest.fetch("display_name"),
          [
            "App ID: #{manifest.fetch("app_id")}",
            "Name: #{manifest.fetch("display_name")}",
            "Default name: #{manifest["default_display_name"] || manifest.fetch("display_name")}",
            "Backend: #{manifest.fetch("backend")}",
            "Executable: #{manifest.fetch("installed_executable")}",
            "Desktop entry: #{manifest["desktop_entry"] || "none"}",
            "Icon: #{active_icon_summary(manifest)}",
            "Sandbox: #{Sandbox.summary(manifest, @settings.load)}",
            "Custom title: #{custom["display_name"] ? "yes" : "no"}",
            "Custom icon: #{custom_icon ? custom_icon["path"] : "no"}",
            "Source: #{manifest.fetch("install_source")}",
            "Update source: #{manifest.dig("update", "source") || "none"}",
            "Installed: #{manifest.fetch("installed_at", "unknown")}"
          ].join("\n")
        )
      end

      def change_title_selected
        manifest = selected_manifest
        return warn_dialog("Select an installed app first.") unless manifest

        ok = QBool.new
        title = QInputDialog.get_text(
          self,
          QString.new("Change Title"),
          QString.new("Application title:"),
          QLineEdit::Normal,
          QString.new(manifest.fetch("display_name")),
          ok
        )
        return unless ok.ok? && title

        result = @customizer.rename(manifest.fetch("app_id"), title.to_s)
        if result.ok?
          refresh_installed
          status_bar.show_message(QString.new("Updated #{result.value.fetch("display_name")}"))
        else
          warn_dialog(result.error)
        end
      rescue StandardError => e
        unexpected_error(e)
      end

      def change_icon_selected
        manifest = selected_manifest
        return warn_dialog("Select an installed app first.") unless manifest

        file = QFileDialog.get_open_file_name(
          self,
          "Choose Icon",
          Dir.home,
          "Icons (*.png *.svg *.xpm);;All files (*)"
        )
        return unless file && !file.empty?

        result = @customizer.change_icon(manifest.fetch("app_id"), file)
        if result.ok?
          refresh_installed
          status_bar.show_message(QString.new("Updated icon for #{result.value.fetch("display_name")}"))
        else
          warn_dialog(result.error)
        end
      end

      def sandbox_selected
        manifest = selected_manifest
        return warn_dialog("Select an installed app first.") unless manifest

        if manifest["backend"] == "flatpak"
          QMessageBox.information(self, "Sandbox", "Flatpak manages sandboxing for #{manifest.fetch("display_name")}.\n\nDepot will show Flatpak permissions in a later permission editor.")
          return
        end
        return warn_dialog("Depot sandboxing is available for AppImage, portable Debian, portable RPM, and portable archive apps.") unless Sandbox.portable?(manifest)

        dialog = SandboxDialog.new(self, manifest, @settings.load)
        return unless dialog.exec == QDialog::Accepted

        result = Sandbox.set(manifest.fetch("app_id"), dialog.values, store: @store, settings: @settings.load)
        if result.ok?
          refresh_installed
          status_bar.show_message(QString.new("Updated sandbox for #{manifest.fetch("display_name")}"))
        else
          warn_dialog(result.error)
        end
      rescue StandardError => e
        unexpected_error(e)
      end

      def reset_selected
        manifest = selected_manifest
        return warn_dialog("Select an installed app first.") unless manifest

        answer = QMessageBox.question(
          self,
          "Reset Properties",
          "Reset #{manifest.fetch("display_name")} to its original title and icon?",
          QMessageBox::Yes | QMessageBox::No
        )
        return unless answer == QMessageBox::Yes

        result = @customizer.reset(manifest.fetch("app_id"))
        if result.ok?
          refresh_installed
          status_bar.show_message(QString.new("Reset properties for #{result.value.fetch("display_name")}"))
        else
          warn_dialog(result.error)
        end
      end

      def uninstall_selected
        manifest = selected_manifest
        return warn_dialog("Select an installed app first.") unless manifest

        answer = QMessageBox.question(
          self,
          "Uninstall",
          "Remove #{manifest.fetch("display_name")} and its Depot-created desktop integration?",
          QMessageBox::Yes | QMessageBox::No
        )
        return unless answer == QMessageBox::Yes

        result = Uninstaller.uninstall(manifest.fetch("app_id"))
        if result.ok?
          QMessageBox.information(self, "Uninstalled", "Removed #{manifest.fetch("display_name")}.")
          refresh_installed
        else
          warn_dialog(result.error)
        end
      end

      def reinstall_selected
        manifest = selected_manifest
        return warn_dialog("Select an installed app first.") unless manifest

        source = manifest["install_source"]
        return warn_dialog("Depot does not know the original installer path for this app.") if source.to_s.empty?
        source = resolved_install_source(source)
        return warn_dialog("Original installer is missing: #{manifest["install_source"]}") unless source

        answer = QMessageBox.question(
          self,
          "Reinstall",
          "Reinstall #{manifest.fetch("display_name")} from its original installer?\n\nDepot will remove and recreate its managed files, desktop entry, icons, and manifest.",
          QMessageBox::Yes | QMessageBox::No
        )
        return unless answer == QMessageBox::Yes

        uninstall = nil
        install = nil
        with_install_progress("Reinstalling #{manifest.fetch("display_name")}...\n\nThis may take a while.") do
          uninstall = Uninstaller.uninstall(manifest.fetch("app_id"))
          install = Installer.install(source, settings: @settings.load) if uninstall.ok?
        end
        return warn_dialog(uninstall.error) unless uninstall.ok?

        if install.ok?
          refreshed = install.value
          QMessageBox.information(self, "Reinstalled", "Reinstalled #{refreshed.fetch("display_name")} as #{refreshed.fetch("app_id")}.")
          refresh_installed
        else
          warn_dialog("Depot removed the old install, but reinstall failed: #{install.error}")
          refresh_installed
        end
      rescue StandardError => e
        unexpected_error(e)
      end

      def refresh_updates
        return unless @updates_table

        enabled = @settings.load.fetch("updates_enabled", true)
        @updates_status.set_text(enabled ? "Updates are enabled." : "Updates are disabled in Settings.")
        @updates_table.set_row_count(0)
        Updater.new(store: @store, settings: @settings).records.each_with_index do |record, row|
          @updates_table.insert_row(row)
          @updates_table.set_item(row, 0, QTableWidgetItem.new(record.fetch("app_id")))
          @updates_table.set_item(row, 1, QTableWidgetItem.new(record.fetch("display_name")))
          @updates_table.set_item(row, 2, QTableWidgetItem.new(record.fetch("method")))
          @updates_table.set_item(row, 3, QTableWidgetItem.new(record.fetch("status")))
          @updates_table.set_item(row, 4, QTableWidgetItem.new(record.fetch("last_updated_at").to_s))
        end
        @updates_table.resize_columns_to_contents
      end

      def set_update_source_selected
        app_id = selected_update_app_id
        return warn_dialog("Select an app first.") unless app_id

        manifest = @store.find(app_id)
        current = manifest&.dig("update", "source").to_s
        ok = QBool.new
        url = QInputDialog.get_text(
          self,
          QString.new("Update Source"),
          QString.new("HTTPS update URL:"),
          QLineEdit::Normal,
          QString.new(current.start_with?("https://") ? current : ""),
          ok
        )
        return unless ok.ok? && url

        result = Updater.new(store: @store, settings: @settings).set_source(app_id, url.to_s.strip)
        if result.ok?
          refresh_updates
          status_bar.show_message(QString.new("Updated source for #{app_id}"))
        else
          warn_dialog(result.error)
        end
      rescue StandardError => e
        unexpected_error(e)
      end

      def update_selected
        return warn_dialog("Updates are disabled in Settings.") unless @settings.load.fetch("updates_enabled", true)

        app_id = selected_update_app_id
        return warn_dialog("Select an app to update first.") unless app_id

        result = with_install_progress("Updating #{app_id}...\n\nThis may take a while.") do
          Updater.new(store: @store, settings: @settings).update(app_id)
        end
        if result.ok?
          QMessageBox.information(self, "Updated", "Updated #{app_id}.")
          refresh_updates
          refresh_installed
        else
          warn_dialog(result.error)
        end
      end

      def update_all
        return warn_dialog("Updates are disabled in Settings.") unless @settings.load.fetch("updates_enabled", true)

        answer = QMessageBox.question(
          self,
          "Update All",
          "Update every app that Depot knows how to update?",
          QMessageBox::Yes | QMessageBox::No
        )
        return unless answer == QMessageBox::Yes

        result = with_install_progress("Updating apps...\n\nThis may take a while.") do
          Updater.new(store: @store, settings: @settings).update_all
        end
        if result.ok?
          QMessageBox.information(self, "Updates", "Finished updating apps.")
        else
          warn_dialog(([result.error] + result.warnings).join("\n"))
        end
        refresh_updates
        refresh_installed
      end

      def save_settings
        values = {
          "warning_verbosity" => @warning_combo.current_text,
          "theme" => @theme_combo.current_text,
          "default_install_location" => "user",
          "sandbox_preference" => @sandbox_combo.current_text,
          "sandbox_profile" => @sandbox_profile_combo.current_text,
          "sandbox_home_access" => @sandbox_home_combo.current_text,
          "sandbox_network" => @sandbox_network_check.checked?,
          "desktop_integration" => @desktop_check.checked?,
          "updates_enabled" => @updates_check.checked?
        }
        @settings.save(values)
        apply_theme(values.fetch("theme"))
        QMessageBox.information(self, "Settings", "Depot settings were saved.")
      end

      def change_page(index)
        @pages.set_current_index(index)
        refresh_installed if index == 1
        refresh_updates if index == 2
      end

      def load_input(path)
        @current_path = path
        @path_edit.set_text(path)
        inspect_current
      end

      private

      def build_ui
        central = QWidget.new
        root = QHBoxLayout.new

        @sidebar = QListWidget.new
        @sidebar.set_fixed_width(170)
        @sidebar.set_object_name("depotSidebar")
        %w[Install Installed Updates Settings About].each { |name| @sidebar.add_item(name) }
        @sidebar.current_row_changed.connect(self, :change_page)

        @pages = QStackedWidget.new
        @pages.add_widget(build_install_page)
        @pages.add_widget(build_installed_page)
        @pages.add_widget(build_updates_page)
        @pages.add_widget(build_settings_page)
        @pages.add_widget(build_about_page)

        root.add_widget(@sidebar)
        root.add_widget(@pages, 1)
        central.set_layout(root)
        set_central_widget(central)
        status_bar.show_message(QString.new("Ready"))
        @sidebar.set_current_row(0)
      end

      def build_install_page
        page = QWidget.new
        layout = QVBoxLayout.new

        logo_path = Assets.logo_path
        if File.exist?(logo_path)
          logo = QLabel.new
          pixmap = QPixmap.new(logo_path)
          logo.set_pixmap(pixmap.scaled(96, 96, Qt::KeepAspectRatio, Qt::SmoothTransformation))
          logo.set_alignment(Qt::AlignCenter)
          layout.add_widget(logo)
        end

        title = QLabel.new("Install software")
        title.set_style_sheet("font-size: 26px; font-weight: 800;")
        title.set_alignment(Qt::AlignCenter)
        layout.add_widget(title)

        subtitle = QLabel.new("Select any Linux programs you'd like to install.")
        subtitle.set_object_name("depotInstallSubtitle")
        subtitle.set_alignment(Qt::AlignCenter)
        layout.add_widget(subtitle)

        drop = DropPanel.new { |path| load_input(path) }
        layout.add_widget(drop)

        row = QHBoxLayout.new
        @path_edit = QLineEdit.new
        @path_edit.set_placeholder_text("Path to package or installer")
        browse = QPushButton.new("Choose File")
        browse.clicked.connect(self, :browse_file)
        inspect = QPushButton.new("Inspect")
        inspect.clicked.connect(self, :inspect_current)
        row.add_widget(@path_edit, 1)
        row.add_widget(browse)
        row.add_widget(inspect)
        layout.add_layout(row)

        @detected_label = QLabel.new("")
        @detected_label.set_object_name("depotDetectedLabel")
        @detected_label.set_word_wrap(true)
        @detected_label.set_visible(false)
        layout.add_widget(@detected_label)

        @summary = QTextEdit.new
        @summary.set_read_only(true)
        @summary.set_minimum_height(220)
        layout.add_widget(@summary, 1)

        @install_button = QPushButton.new("Install Software")
        @install_button.set_enabled(false)
        @install_button.clicked.connect(self, :install_current)
        layout.add_widget(@install_button)

        page.set_layout(layout)
        page
      end

      def build_installed_page
        page = QWidget.new
        layout = QVBoxLayout.new

        title = QLabel.new("Installed Apps")
        title.set_style_sheet("font-size: 24px; font-weight: 700;")
        layout.add_widget(title)

        @apps_table = InstalledAppsTable.new(self)
        @apps_table.set_horizontal_header_labels(QStringList.new << "ID" << "Name" << "Backend" << "Installed")
        @apps_table.set_selection_behavior(QAbstractItemView::SelectRows)
        @apps_table.set_selection_mode(QAbstractItemView::SingleSelection)
        layout.add_widget(@apps_table, 1)

        buttons = QHBoxLayout.new
        refresh = QPushButton.new("Refresh")
        refresh.clicked.connect(self, :refresh_installed)
        launch = QPushButton.new("Launch")
        launch.clicked.connect(self, :launch_selected)
        info = QPushButton.new("Info")
        info.clicked.connect(self, :info_selected)
        rename = QPushButton.new("Rename")
        rename.clicked.connect(self, :change_title_selected)
        icon = QPushButton.new("Icon")
        icon.clicked.connect(self, :change_icon_selected)
        sandbox = QPushButton.new("Sandbox")
        sandbox.clicked.connect(self, :sandbox_selected)
        reset = QPushButton.new("Reset Properties")
        reset.clicked.connect(self, :reset_selected)
        reinstall = QPushButton.new("Reinstall")
        reinstall.clicked.connect(self, :reinstall_selected)
        uninstall = QPushButton.new("Uninstall")
        uninstall.clicked.connect(self, :uninstall_selected)
        buttons.add_widget(refresh)
        buttons.add_stretch
        buttons.add_widget(launch)
        buttons.add_widget(info)
        buttons.add_widget(rename)
        buttons.add_widget(icon)
        buttons.add_widget(sandbox)
        buttons.add_widget(reset)
        buttons.add_widget(reinstall)
        buttons.add_widget(uninstall)
        layout.add_layout(buttons)

        page.set_layout(layout)
        page
      end

      def build_updates_page
        page = QWidget.new
        layout = QVBoxLayout.new

        title = QLabel.new("Updates")
        title.set_style_sheet("font-size: 24px; font-weight: 700;")
        layout.add_widget(title)

        @updates_status = QLabel.new("Updates are enabled.")
        @updates_status.set_object_name("depotInstallSubtitle")
        layout.add_widget(@updates_status)

        @updates_table = QTableWidget.new(0, 5)
        @updates_table.set_horizontal_header_labels(QStringList.new << "ID" << "Name" << "Method" << "Status" << "Last Updated")
        @updates_table.set_selection_behavior(QAbstractItemView::SelectRows)
        @updates_table.set_selection_mode(QAbstractItemView::SingleSelection)
        layout.add_widget(@updates_table, 1)

        buttons = QHBoxLayout.new
        refresh = QPushButton.new("Refresh")
        refresh.clicked.connect(self, :refresh_updates)
        set_url = QPushButton.new("Set URL")
        set_url.clicked.connect(self, :set_update_source_selected)
        selected = QPushButton.new("Update Selected")
        selected.clicked.connect(self, :update_selected)
        all = QPushButton.new("Update All")
        all.clicked.connect(self, :update_all)
        buttons.add_widget(refresh)
        buttons.add_stretch
        buttons.add_widget(set_url)
        buttons.add_widget(selected)
        buttons.add_widget(all)
        layout.add_layout(buttons)

        page.set_layout(layout)
        page
      end

      def build_settings_page
        page = QWidget.new
        layout = QVBoxLayout.new

        title = QLabel.new("Settings")
        title.set_style_sheet("font-size: 24px; font-weight: 700;")
        layout.add_widget(title)

        form = QFormLayout.new
        @warning_combo = QComboBox.new
        %w[quiet normal detailed].each { |value| @warning_combo.add_item(value) }
        @theme_combo = QComboBox.new
        %w[system light dark].each { |value| @theme_combo.add_item(value) }
        @sandbox_combo = QComboBox.new
        %w[ask prefer-off prefer-on].each { |value| @sandbox_combo.add_item(value) }
        @sandbox_profile_combo = QComboBox.new
        %w[relaxed balanced strict].each { |value| @sandbox_profile_combo.add_item(value) }
        @sandbox_home_combo = QComboBox.new
        %w[isolated documents full].each { |value| @sandbox_home_combo.add_item(value) }
        @sandbox_network_check = QCheckBox.new("Allow network access in new app sandboxes")
        @desktop_check = QCheckBox.new("Create desktop launchers and icons")
        @updates_check = QCheckBox.new("Enable updates")

        form.add_row(QString.new("Warnings"), @warning_combo)
        form.add_row(QString.new("Theme"), @theme_combo)
        form.add_row(QString.new("Sandbox default"), @sandbox_combo)
        form.add_row(QString.new("Sandbox profile"), @sandbox_profile_combo)
        form.add_row(QString.new("Sandbox home"), @sandbox_home_combo)
        form.add_row(QString.new("Sandbox network"), @sandbox_network_check)
        form.add_row(QString.new("Desktop integration"), @desktop_check)
        form.add_row(QString.new("Updates"), @updates_check)
        layout.add_layout(form)

        save = QPushButton.new("Save Settings")
        save.clicked.connect(self, :save_settings)
        layout.add_widget(save)
        layout.add_stretch

        page.set_layout(layout)
        page
      end

      def build_about_page
        page = QWidget.new
        layout = QVBoxLayout.new
        logo_path = Assets.logo_path
        if File.exist?(logo_path)
          logo = QLabel.new
          pixmap = QPixmap.new(logo_path)
          logo.set_pixmap(pixmap.scaled(164, 164, Qt::KeepAspectRatio, Qt::SmoothTransformation))
          logo.set_alignment(Qt::AlignCenter)
          layout.add_widget(logo)
        end

        text = QLabel.new("Depot\nUniversal Linux application installer and desktop integration layer.\n\nThis build installs software through Depot manifests, desktop launchers, icons, settings, and clean uninstall tracking. Additional backends plug into the same flow.")
        text.set_alignment(Qt::AlignCenter)
        text.set_word_wrap(true)
        layout.add_widget(text)
        layout.add_stretch
        page.set_layout(layout)
        page
      end

      def load_settings_controls
        values = @settings.load
        set_combo(@warning_combo, values.fetch("warning_verbosity", "normal"))
        set_combo(@theme_combo, values.fetch("theme", "system"))
        set_combo(@sandbox_combo, values.fetch("sandbox_preference", "ask"))
        set_combo(@sandbox_profile_combo, values.fetch("sandbox_profile", "balanced"))
        set_combo(@sandbox_home_combo, values.fetch("sandbox_home_access", "documents"))
        @sandbox_network_check.set_checked(values.fetch("sandbox_network", true))
        @desktop_check.set_checked(values.fetch("desktop_integration", true))
        @updates_check.set_checked(values.fetch("updates_enabled", true))
      end

      def set_combo(combo, value)
        index = combo.find_text(value)
        combo.set_current_index(index) if index && index >= 0
      end

      def apply_theme(theme)
        set_style_sheet(base_stylesheet(theme))
      end

      def base_stylesheet(theme)
        palette = case theme
        when "dark"
          {
            bg: "#17191d", panel: "#20242a", field: "#242932", text: "#f2f4f8",
            muted: "#aeb6c2", border: "#3b424d", accent: "#2f6fed", accent_hover: "#3f7cff"
          }
        when "light"
          {
            bg: "#f5f6f8", panel: "#ffffff", field: "#ffffff", text: "#17191d",
            muted: "#5f6875", border: "#cfd5dd", accent: "#245fd6", accent_hover: "#1f55bf"
          }
        else
          {
            bg: "#f5f6f8", panel: "#ffffff", field: "#ffffff", text: "#17191d",
            muted: "#5f6875", border: "#cfd5dd", accent: "#245fd6", accent_hover: "#1f55bf"
          }
        end

        <<~CSS
          QMainWindow, QWidget {
            background: #{palette.fetch(:bg)};
            color: #{palette.fetch(:text)};
            font-size: 14px;
          }
          QLabel#depotDropTitle {
            font-size: 22px;
            font-weight: 700;
          }
          QLabel#depotDropHint {
            color: #{palette.fetch(:muted)};
          }
          QLabel#depotInstallSubtitle {
            color: #{palette.fetch(:muted)};
            font-size: 14px;
          }
          QLabel#depotDetectedLabel {
            background: #{palette.fetch(:panel)};
            color: #{palette.fetch(:text)};
            border: 1px solid #{palette.fetch(:border)};
            border-radius: 6px;
            padding: 10px 12px;
            font-weight: 700;
          }
          QFrame#depotDropPanel {
            background: #{palette.fetch(:panel)};
            border: 2px dashed #{palette.fetch(:border)};
            border-radius: 8px;
          }
          QFrame#depotDropPanel[dragActive="true"] {
            border-color: #{palette.fetch(:accent)};
            background: #{palette.fetch(:field)};
          }
          QListWidget#depotSidebar, QTextEdit, QLineEdit, QTableWidget, QComboBox {
            background: #{palette.fetch(:field)};
            color: #{palette.fetch(:text)};
            border: 1px solid #{palette.fetch(:border)};
            border-radius: 6px;
          }
          QListWidget#depotSidebar::item {
            min-height: 38px;
            padding-left: 12px;
            border-radius: 4px;
          }
          QListWidget#depotSidebar::item:selected {
            background: #{palette.fetch(:accent)};
            color: white;
          }
          QPushButton {
            background: #{palette.fetch(:accent)};
            color: white;
            padding: 8px 14px;
            border: 0;
            border-radius: 6px;
          }
          QPushButton:hover {
            background: #{palette.fetch(:accent_hover)};
          }
          QPushButton:disabled {
            background: #{palette.fetch(:border)};
            color: #{palette.fetch(:muted)};
          }
        CSS
      end

      def summary_for(inspection)
        lines = [
          "Package",
          "  Name: #{inspection.display_name}",
          "  Format: #{inspection.format} (#{inspection.confidence})",
          "  Size: #{format_bytes(inspection.size)}",
          "  SHA-256: #{inspection.sha256 || "calculated during install"}",
          "  Executable file: #{inspection.executable ? "yes" : "no"}"
        ]
        if inspection.deb?
          dependencies = dependency_names(inspection.metadata["depends"])
          scripts = inspection.metadata.fetch("maintainer_scripts", [])
          desktops = inspection.metadata.fetch("desktop_entries", [])
          lines << ""
          lines << "Debian package:"
          lines << "  Package: #{inspection.metadata["package"] || "unknown"}"
          lines << "  Version: #{inspection.metadata["version"] || "unknown"}"
          lines << "  Architecture: #{inspection.metadata["architecture"] || "unknown"}"
          lines << "  Dependencies: #{dependencies.empty? ? "none declared" : dependency_summary(dependencies)}"
          lines << "  Maintainer scripts: #{scripts.empty? ? "none" : scripts.join(", ")}"
          lines << "  Desktop entries: #{desktops.empty? ? "none" : "#{desktops.length} found; using #{inspection.metadata["primary_desktop_entry"]}"}"
          lines << "  Portable install: extracts into Depot; does not run apt, dpkg, sudo, or maintainer scripts"
        elsif inspection.archive?
          scripts = inspection.metadata.fetch("script_entries", [])
          markers = inspection.metadata.fetch("source_markers", [])
          executables = inspection.metadata.fetch("executable_candidates", [])
          desktops = inspection.metadata.fetch("desktop_entries", [])
          lines << ""
          lines << "Portable archive:"
          lines << "  Archive root: #{inspection.metadata["archive_root"] || "mixed"}"
          lines << "  Executable candidates: #{executables.empty? ? "none" : executables.first(6).join(", ")}"
          lines << "  Desktop entries: #{desktops.empty? ? "none; Depot will generate one if possible" : "#{desktops.length} found; using #{inspection.metadata["primary_desktop_entry"]}"}"
          lines << "  Icons/images: #{inspection.metadata.fetch("icon_count", 0)} found"
          lines << "  Installer-like scripts: #{scripts.empty? ? "none" : scripts.first(6).join(", ")}"
          lines << "  Source/build markers: #{markers.empty? ? "none" : markers.join(", ")}"
          lines << "  Portable install: extracts into Depot; does not run scripts"
        elsif inspection.rpm?
          requirements = rpm_requirement_names(inspection.metadata["requires"])
          scriptlets = inspection.metadata.fetch("scriptlets", [])
          desktops = inspection.metadata.fetch("desktop_entries", [])
          lines << ""
          lines << "RPM package:"
          lines << "  Package: #{inspection.metadata["package"] || "unknown"}"
          lines << "  Version: #{rpm_version_label(inspection.metadata)}"
          lines << "  Architecture: #{inspection.metadata["architecture"] || "unknown"}"
          lines << "  Payload: #{inspection.metadata["payload_format"] || "unknown"} / #{inspection.metadata["payload_compressor"] || "unknown"}"
          lines << "  Requirements: #{requirements.empty? ? "none declared" : dependency_summary(requirements)}"
          lines << "  Scriptlets: #{scriptlets.empty? ? "none" : scriptlets.join(", ")}"
          lines << "  Desktop entries: #{desktops.empty? ? "none" : "#{desktops.length} found; using #{inspection.metadata["primary_desktop_entry"]}"}"
          lines << "  Portable install: extracts into Depot; does not run rpm, dnf, zypper, sudo, or scriptlets"
        elsif inspection.flatpakref?
          lines << ""
          lines << "Flatpak reference:"
          lines << "  Flatpak ID: #{inspection.metadata["name"] || "unknown"}"
          lines << "  Branch: #{inspection.metadata["branch"] || "master"}"
          lines << "  Remote: #{inspection.metadata["suggest_remote_name"] || "none"}"
          lines << "  URL: #{inspection.metadata["url"] || "unknown"}"
          lines << "  Runtime ref: #{inspection.metadata["is_runtime"] ? "yes" : "no"}"
          lines << "  Embedded GPG key: #{inspection.metadata["gpg_key_present"] ? "yes" : "no"}"
          lines << "  Install mode: Flatpak handles download, runtime dependencies, sandboxing, and desktop integration"
        end
        lines << ""
        lines << "Warnings:"
        lines.concat(list_or_none(inspection.warnings))
        lines << ""
        lines << "Risks:"
        lines.concat(list_or_none(inspection.risks))
        lines.join("\n")
      end

      def list_or_none(items)
        return ["  none"] if items.empty?

        items.map { |item| "  - #{item}" }
      end

      def selected_manifest
        row = @apps_table.current_row
        return nil if row.nil? || row.negative?

        item = @apps_table.item(row, 0)
        return nil unless item

        @store.find(item.text)
      end

      def selected_update_app_id
        row = @updates_table.current_row
        return nil if row.nil? || row.negative?

        item = @updates_table.item(row, 0)
        item&.text
      end

      def resolved_install_source(source)
        SourceResolver.resolve(source)
      end

      def installable_inspection?(inspection)
        inspection&.appimage? || inspection&.deb? || inspection&.archive? || inspection&.rpm? || inspection&.flatpakref?
      end

      def install_prompt(inspection)
        base_actions = [
          "Record a Depot manifest",
          "Prepare desktop integration",
          "Track uninstall behavior"
        ]
        return prompt_message(inspection, base_actions.unshift("Copy the app into your user application folder"), []) unless inspection.deb? || inspection.archive? || inspection.rpm? || inspection.flatpakref?

        if inspection.archive?
          scripts = inspection.metadata.fetch("script_entries", [])
          markers = inspection.metadata.fetch("source_markers", [])
          actions = ["Extract the archive user-locally", "Infer launcher/icon integration", "Record uninstall tracking"]
          notes = ["Installer scripts are not run"]
          notes << "Scripts found: #{scripts.first(6).join(", ")}" unless scripts.empty?
          notes << "Source/build markers found: #{markers.join(", ")}" unless markers.empty?
          return prompt_message(inspection, actions, notes)
        end

        if inspection.rpm?
          requirements = rpm_requirement_names(inspection.metadata["requires"])
          scriptlets = inspection.metadata.fetch("scriptlets", [])
          actions = ["Extract the RPM payload user-locally", "Rewrite launchers/icons for Depot", "Record uninstall tracking"]
          notes = ["No rpm, dnf, zypper, sudo, or scriptlets"]
          notes << "Requirements are not installed automatically: #{dependency_summary(requirements)}" unless requirements.empty?
          notes << "Scriptlets will not be run: #{scriptlets.join(", ")}" unless scriptlets.empty?
          return prompt_message(inspection, actions, notes)
        end

        if inspection.flatpakref?
          actions = ["Install through Flatpak in user mode", "Track the app in Depot", "Use Flatpak for launch/uninstall"]
          notes = [
            "Flatpak ID: #{inspection.metadata["name"] || inspection.display_name}",
            "Remote: #{inspection.metadata["suggest_remote_name"] || "none"}",
            "Flatpak manages sandboxing and runtime dependencies"
          ]
          return prompt_message(inspection, actions, notes)
        end

        dependencies = dependency_names(inspection.metadata["depends"])
        scripts = inspection.metadata.fetch("maintainer_scripts", [])
        actions = ["Extract the Debian payload user-locally", "Rewrite launchers/icons for Depot", "Record uninstall tracking"]
        notes = ["No apt, dpkg, sudo, or maintainer scripts"]
        notes << "Dependencies are not installed automatically: #{dependency_summary(dependencies)}" unless dependencies.empty?
        notes << "Scripts will not be run: #{scripts.join(", ")}" unless scripts.empty?
        prompt_message(inspection, actions, notes)
      end

      def prompt_message(inspection, actions, notes)
        [
          "#{inspection.display_name}",
          "#{inspection.format} install",
          "",
          "What Depot will do:",
          *actions.map { |action| "  - #{action}" },
          ("Notes:" unless notes.empty?),
          *notes.map { |note| "  - #{note}" },
          "",
          "Install #{inspection.metadata["package"] || inspection.metadata["name"] || inspection.display_name}?"
        ].compact.join("\n")
      end

      def detected_summary(inspection)
        backend = case inspection.format
                  when "flatpakref" then "Flatpak"
                  when "deb" then "Debian portable"
                  when "rpm" then "RPM portable"
                  when "appimage" then "AppImage"
                  when "tar.gz", "tar.xz", "tar.zst" then "Portable archive"
                  else inspection.format
                  end
        "#{backend} detected: #{inspection.display_name} - #{format_bytes(inspection.size)}"
      end

      def format_bytes(size)
        return "unknown" unless size

        units = %w[B KB MB GB]
        value = size.to_f
        unit = units.shift
        while value >= 1024 && units.any?
          value /= 1024
          unit = units.shift
        end
        value >= 10 || unit == "B" ? "#{value.round} #{unit}" : "#{value.round(1)} #{unit}"
      end

      def with_install_progress(message)
        dialog = QMessageBox.new(
          QMessageBox::Information,
          QString.new("Depot"),
          QString.new(message),
          QMessageBox::NoButton.to_qflags,
          self
        )
        dialog.set_option(QMessageBox::DontUseNativeDialog, true)
        dialog.set_window_title(QString.new("Depot"))
        dialog.set_modal(true)
        dialog.set_window_modality(Qt::ApplicationModal)
        dialog.set_style_sheet(install_progress_message_style)
        dialog.set_fixed_size(460, 150)
        dialog.show
        QApplication.process_events

        result = nil
        error = nil
        done = false
        worker = Thread.new do
          begin
            result = yield
          rescue StandardError => e
            error = e
          ensure
            done = true
          end
        end

        until done
          QApplication.process_events
          sleep 0.05
        end
        worker.join
        raise error if error

        result
      ensure
        if dialog
          dialog.close
          QApplication.process_events
        end
      end

      def install_progress_name(inspection)
        inspection&.metadata&.fetch("package", nil) || inspection&.display_name || "software"
      end

      def install_progress_message_style
        <<~CSS
          QMessageBox {
            background-color: #ffffff;
            color: #15171a;
            border: 1px solid #cfd5dd;
          }
          QMessageBox QLabel {
            background-color: #ffffff;
            color: #15171a;
            font-size: 15px;
            font-weight: 700;
            padding: 10px;
          }
          QMessageBox QLabel#qt_msgbox_label {
            min-width: 340px;
          }
          QMessageBox QPushButton {
            background-color: #245fd6;
            color: #ffffff;
          }
        CSS
      end

      def dependency_names(depends)
        depends.to_s.split(",").map do |dependency|
          dependency.split("|").first.to_s.strip.sub(/\s*\(.+\)\z/, "")
        end.reject(&:empty?).uniq
      end

      def dependency_summary(dependencies)
        shown = dependencies.first(6).join(", ")
        extra = dependencies.length - 6
        extra.positive? ? "#{dependencies.length} dependencies, including #{shown}, and #{extra} more" : shown
      end

      def rpm_requirement_names(requires)
        Array(requires).map do |requirement|
          requirement.to_s.sub(/\s*\(.+\)\z/, "")
        end.reject { |name| name.empty? || name.start_with?("rpmlib(") }.uniq
      end

      def rpm_version_label(metadata)
        [metadata["version"], metadata["release"]].compact.join("-").then { |value| value.empty? ? "unknown" : value }
      end

      def active_icon_summary(manifest)
        custom = manifest["custom_icon"]
        return custom["path"] if custom && custom["path"].to_s != ""

        manifest["default_icon_name"] || (manifest["icons"].to_a.any? ? manifest.fetch("app_id") : "none")
      end

      def warn_dialog(message)
        QMessageBox.warning(self, "Depot", message)
      end

      def unexpected_error(error)
        warn_dialog("Depot hit an interface error: #{error.message}")
      end
    end
  end
end
