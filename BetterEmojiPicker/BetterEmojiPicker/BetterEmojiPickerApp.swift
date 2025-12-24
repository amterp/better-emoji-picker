//
//  BetterEmojiPickerApp.swift
//  BetterEmojiPicker
//
//  The main entry point for the Better Emoji Picker (BEP) application.
//  This sets up the menu bar app, global hotkey, and picker window.
//

import SwiftUI
import AppKit

/// The main application structure.
///
/// BEP runs as a menu bar app (no dock icon) that:
/// 1. Shows a menu bar icon with status and preferences
/// 2. Registers a global hotkey (Ctrl+Cmd+Space)
/// 3. Shows/hides the floating emoji picker when the hotkey is pressed
///
/// SwiftUI notes for newcomers:
/// - `@main` marks this as the application entry point
/// - `@NSApplicationDelegateAdaptor` connects SwiftUI to AppKit's delegate pattern
/// - `MenuBarExtra` creates a menu bar item (macOS 13+)
@main
struct BetterEmojiPickerApp: App {

    /// The app delegate handles low-level app lifecycle events.
    /// We need this for registering global hotkeys (not possible in pure SwiftUI).
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar item with dropdown menu
        MenuBarExtra("BEP", systemImage: "face.smiling") {
            MenuBarView(appDelegate: appDelegate)
        }
        // We don't use WindowGroup because this is a menu bar-only app
        // The picker appears in a floating panel, not a regular window
    }
}

// MARK: - Menu Bar View

/// The dropdown menu shown when clicking the menu bar icon.
struct MenuBarView: View {
    @ObservedObject var appDelegate: AppDelegate

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status section
            statusSection

            Divider()

            // Actions
            Button("Show Emoji Picker") {
                appDelegate.showPicker()
            }
            .keyboardShortcut("e", modifiers: [.command])

            Divider()

            // App info
            Text("Shortcut: ⌃⌘Space")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            // Quit button
            Button("Quit BEP") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
    }

    /// Status section showing permission and hotkey status
    @ViewBuilder
    private var statusSection: some View {
        if appDelegate.hasAccessibilityPermission {
            Label("Ready", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
        } else {
            Button {
                appDelegate.requestAccessibilityPermission()
            } label: {
                Label("Grant Accessibility Permission", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            }
        }
    }
}

// MARK: - App Delegate

/// Handles application lifecycle and coordinates the picker system.
///
/// Why an AppDelegate?
/// - SwiftUI's declarative approach doesn't support global hotkey registration
/// - We need to run code at specific app lifecycle points
/// - AppKit's NSApplicationDelegate provides these hooks
///
/// This class:
/// 1. Initializes all services (EmojiStore, HotkeyService, PasteService)
/// 2. Registers the global hotkey
/// 3. Creates and manages the floating picker panel
/// 4. Coordinates emoji insertion
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {

    // MARK: - Published State

    /// Whether we have accessibility permission (for showing status in menu)
    @Published var hasAccessibilityPermission: Bool = false

    // MARK: - Services

    /// The emoji data store
    private var emojiStore: EmojiStore!

    /// The picker view model
    private var pickerViewModel: PickerViewModel!

    /// The floating panel containing the picker
    private var pickerPanel: FloatingPanel?

    // MARK: - App Lifecycle

    /// Called when the application finishes launching.
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 BEP: Application launched")

        // Initialize services
        initializeServices()

        // Check and request permissions
        checkPermissions()

        // Register global hotkey
        registerHotkey()

        // Hide dock icon (should already be set via Info.plist, but ensure it)
        NSApp.setActivationPolicy(.accessory)
    }

    /// Called when the application is about to terminate.
    func applicationWillTerminate(_ notification: Notification) {
        print("👋 BEP: Application terminating")

        // Unregister hotkey
        HotkeyService.shared.unregisterAll()
    }

    // MARK: - Initialization

    /// Initializes all services and view models.
    private func initializeServices() {
        // Create the emoji store (loads emoji data)
        emojiStore = EmojiStore()

        // Create the picker view model
        pickerViewModel = PickerViewModel(emojiStore: emojiStore)
    }

    // MARK: - Permissions

    /// Checks current permission status.
    private func checkPermissions() {
        hasAccessibilityPermission = PasteService.shared.hasPermission()

        if !hasAccessibilityPermission {
            print("⚠️ BEP: Accessibility permission not granted")
        }
    }

    /// Requests accessibility permission from the user.
    func requestAccessibilityPermission() {
        PasteService.shared.requestPermission()

        // Check again after a delay (permission granted async)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.checkPermissions()
        }
    }

    // MARK: - Hotkey Registration

    /// Registers the global hotkey (Ctrl+Cmd+Space).
    private func registerHotkey() {
        let success = HotkeyService.shared.register(
            keyCode: KeyCode.space,
            modifiers: ModifierFlags.controlCommand,
            handler: { [weak self] in
                Task { @MainActor in
                    self?.togglePicker()
                }
            }
        )

        if !success {
            print("⚠️ BEP: Failed to register hotkey. The system shortcut may still be enabled.")
        }
    }

    // MARK: - Picker Management

    /// Shows the emoji picker.
    func showPicker() {
        // Create panel if needed
        if pickerPanel == nil {
            createPickerPanel()
        }

        // Position and show
        pickerPanel?.positionNearMouse()
        pickerPanel?.orderFrontRegardless()
        pickerPanel?.makeKey()

        // Notify view model
        pickerViewModel.onShow()
    }

    /// Hides the emoji picker.
    func hidePicker() {
        pickerPanel?.orderOut(nil)
        pickerViewModel.onHide()
    }

    /// Toggles the emoji picker visibility.
    func togglePicker() {
        if pickerPanel?.isVisible == true {
            hidePicker()
        } else {
            showPicker()
        }
    }

    /// Creates the floating picker panel.
    private func createPickerPanel() {
        pickerPanel = FloatingPanel {
            PickerView(
                viewModel: self.pickerViewModel,
                onInsertEmoji: { [weak self] emoji in
                    self?.insertEmoji(emoji)
                },
                onDismiss: { [weak self] in
                    self?.hidePicker()
                }
            )
        }
    }

    // MARK: - Emoji Insertion

    /// Inserts an emoji into the currently focused application.
    private func insertEmoji(_ emoji: Emoji) {
        // Check permission
        guard PasteService.shared.hasPermission() else {
            print("⚠️ BEP: Cannot insert emoji - no accessibility permission")
            requestAccessibilityPermission()
            return
        }

        // Paste the emoji
        let success = PasteService.shared.paste(text: emoji.emoji)

        if success {
            print("✅ BEP: Inserted \(emoji.emoji)")
        } else {
            print("⚠️ BEP: Failed to insert emoji")
        }

        // Note: We don't hide the picker here!
        // This is a key feature - the picker stays open for multiple selections.
    }
}
