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

            Button("Setup Assistant...") {
                appDelegate.showSetupWizard()
            }

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
                appDelegate.showSetupWizard()
            } label: {
                Label("Setup Required", systemImage: "exclamationmark.triangle.fill")
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

    /// The setup wizard view model
    private var setupViewModel: SetupViewModel!

    /// The floating panel containing the picker
    private var pickerPanel: FloatingPanel?

    /// The setup wizard window
    private var setupWindow: NSWindow?

    /// The app that was frontmost before we showed the picker
    /// Used to return focus for emoji insertion
    private var previousApp: NSRunningApplication?

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

        // Show setup wizard on first run
        if !SetupViewModel.hasCompletedSetup() {
            showSetupWizard()
        }
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

        // Create the setup view model
        setupViewModel = SetupViewModel()
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
        // Remember the frontmost app so we can return focus for pasting
        previousApp = NSWorkspace.shared.frontmostApplication

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
                onCopyEmoji: { [weak self] emoji in
                    self?.copyEmoji(emoji)
                },
                onDismiss: { [weak self] in
                    self?.hidePicker()
                }
            )
        }
    }

    // MARK: - Setup Wizard

    /// Shows the setup wizard window.
    func showSetupWizard() {
        // Reset the view model for a fresh wizard experience
        setupViewModel = SetupViewModel()

        // Always recreate the window to ensure fresh state
        let wizardView = SetupWizardView(viewModel: setupViewModel) { [weak self] in
            self?.closeSetupWizard()
            // Refresh permission status after setup
            self?.checkPermissions()
        }

        setupWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        setupWindow?.contentView = NSHostingView(rootView: wizardView)
        setupWindow?.title = "Setup BEP"
        setupWindow?.isReleasedWhenClosed = false
        setupWindow?.center()

        setupWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Closes the setup wizard window.
    private func closeSetupWizard() {
        setupWindow?.close()
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

        // Get the target process ID before we do anything
        let targetPID = previousApp?.processIdentifier

        // Resign key status from our panel so paste doesn't go to our search field
        pickerPanel?.resignKey()

        // Activate the previous app
        previousApp?.activate(options: .activateIgnoringOtherApps)

        // Paste with target process ID for reliable delivery
        DispatchQueue.main.async { [weak self] in
            let success = PasteService.shared.paste(text: emoji.emoji, targetPID: targetPID)

            if success {
                print("✅ BEP: Inserted \(emoji.emoji)")
            } else {
                print("⚠️ BEP: Failed to insert emoji")
            }

            // Restore key status after a brief delay to ensure paste events are processed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                self?.pickerPanel?.makeKey()
            }
        }
    }

    // MARK: - Emoji Copy

    /// Copies an emoji to the clipboard without pasting.
    private func copyEmoji(_ emoji: Emoji) {
        PasteService.shared.copyToClipboard(text: emoji.emoji)
        print("📋 BEP: Copied \(emoji.emoji) to clipboard")
    }
}
