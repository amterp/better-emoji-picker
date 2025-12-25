//
//  SettingsView.swift
//  BetterEmojiPicker
//
//  User preferences window for configuring BEP.
//  Uses native macOS Settings scene with TabView.
//

import SwiftUI
import ServiceManagement

/// Main settings view with tabs for different setting categories.
struct SettingsView: View {
    @ObservedObject var settingsService: SettingsService
    let emojiStore: EmojiStoreProtocol

    var body: some View {
        TabView {
            GeneralSettingsView(settingsService: settingsService)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            AboutSettingsView(emojiStore: emojiStore)
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(minWidth: 450, minHeight: 300)
        .frame(idealWidth: 480, idealHeight: 350)
    }
}

// MARK: - General Settings Tab

/// General settings: frecency, clipboard, startup
struct GeneralSettingsView: View {
    @ObservedObject var settingsService: SettingsService
    @State private var launchAtLogin: Bool = false

    var body: some View {
        Form {
            Section {
                Picker("Rows in Recent section", selection: Binding(
                    get: { settingsService.settings.frecencyRows },
                    set: { newValue in settingsService.update { $0.frecencyRows = newValue } }
                )) {
                    ForEach(1...5, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
            } header: {
                Label("Recent Emojis", systemImage: "clock")
            } footer: {
                Text("Frecency combines frequency and recency. More rows show more of your commonly used emojis.")
            }

            Section {
                Picker("Restore delay", selection: Binding(
                    get: { settingsService.settings.clipboardRestoreDelay },
                    set: { newValue in settingsService.update { $0.clipboardRestoreDelay = newValue } }
                )) {
                    ForEach([50, 100, 150, 200, 250, 300, 400, 500], id: \.self) { value in
                        Text("\(value) ms").tag(value)
                    }
                }
            } header: {
                Label("Clipboard", systemImage: "doc.on.clipboard")
            } footer: {
                Text("When inserting emojis, BEP temporarily uses your clipboard. This delay determines how long to wait before restoring your original clipboard contents.")
            }

            Section {
                Toggle("Launch BEP at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        updateLaunchAtLogin(newValue)
                    }
            } header: {
                Label("Startup", systemImage: "power")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .onAppear {
            loadLaunchAtLoginState()
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

// MARK: - About Tab

/// About view with app info and reset option
struct AboutSettingsView: View {
    let emojiStore: EmojiStoreProtocol
    @State private var showResetConfirmation = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // App icon and info
            VStack(spacing: 12) {
                Image(systemName: "face.smiling")
                    .font(.system(size: 64))
                    .foregroundStyle(.linearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                Text("Better Emoji Picker")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Version \(appVersion)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("A fast, keyboard-driven emoji picker for macOS")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Actions
            VStack(spacing: 12) {
                Divider()

                HStack(spacing: 20) {
                    Link(destination: URL(string: "https://github.com/AntonioCiolworx/BetterEmojiPicker")!) {
                        Label("GitHub", systemImage: "link")
                    }

                    Button("Reset Frecency Data...") {
                        showResetConfirmation = true
                    }
                    .foregroundStyle(.red)
                }
                .font(.subheadline)
            }
            .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog(
            "Reset Frecency Data?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                emojiStore.clearFrecencyData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will clear your emoji usage history. The Recent section will be empty until you use emojis again.")
        }
    }
}
