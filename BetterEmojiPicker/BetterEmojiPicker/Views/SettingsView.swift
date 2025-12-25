//
//  SettingsView.swift
//  BetterEmojiPicker
//
//  User preferences window for configuring BEP.
//

import SwiftUI
import ServiceManagement

/// The settings window content.
struct SettingsView: View {

    @ObservedObject var settingsService: SettingsService
    let emojiStore: EmojiStoreProtocol

    @State private var launchAtLogin: Bool = false
    @State private var showResetConfirmation = false

    var body: some View {
        Form {
            recentEmojisSection
            clipboardSection
            startupSection
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 280)
        .onAppear {
            loadLaunchAtLoginState()
        }
        .confirmationDialog(
            "Reset Frecency Data?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                emojiStore.clearFrecencyData()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will clear your emoji usage history. The Recent section will be empty until you use emojis again.")
        }
    }

    // MARK: - Sections

    private var recentEmojisSection: some View {
        Section {
            Stepper(
                "Rows in Recent section: \(settingsService.settings.frecencyRows)",
                value: Binding(
                    get: { settingsService.settings.frecencyRows },
                    set: { newValue in
                        settingsService.update { $0.frecencyRows = newValue }
                    }
                ),
                in: 1...5
            )

            Button("Reset Frecency Data...") {
                showResetConfirmation = true
            }
            .foregroundColor(.red)
        } header: {
            Text("Recent Emojis")
        } footer: {
            Text("Frecency combines frequency and recency. More rows show more of your commonly used emojis.")
        }
    }

    private var clipboardSection: some View {
        Section {
            Stepper(
                "Restore delay: \(settingsService.settings.clipboardRestoreDelay)ms",
                value: Binding(
                    get: { settingsService.settings.clipboardRestoreDelay },
                    set: { newValue in
                        settingsService.update { $0.clipboardRestoreDelay = newValue }
                    }
                ),
                in: 50...1000,
                step: 50
            )
        } header: {
            Text("Clipboard")
        } footer: {
            Text("When inserting emojis, BEP temporarily uses your clipboard. This delay determines how long to wait before restoring your original clipboard contents.")
        }
    }

    private var startupSection: some View {
        Section {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { newValue in
                    updateLaunchAtLogin(newValue)
                }
        } header: {
            Text("Startup")
        }
    }

    // MARK: - Launch at Login

    private func loadLaunchAtLoginState() {
        if #available(macOS 13.0, *) {
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("⚠️ BEP: Failed to update launch-at-login: \(error)")
            }
        }
    }
}
