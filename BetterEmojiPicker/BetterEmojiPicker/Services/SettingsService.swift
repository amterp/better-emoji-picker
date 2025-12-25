//
//  SettingsService.swift
//  BetterEmojiPicker
//
//  Manages application settings stored as TOML.
//  Settings are stored at ~/.config/bep/settings.toml
//

import Foundation
import TOMLKit

/// Manages loading and saving of application settings to a TOML file.
///
/// Settings are stored at `~/.config/bep/settings.toml` which follows
/// XDG Base Directory conventions and makes the config git-friendly.
///
/// Usage:
/// ```swift
/// // Read a setting
/// let rows = SettingsService.shared.settings.frecencyRows
///
/// // Update a setting
/// SettingsService.shared.update { $0.frecencyRows = 3 }
/// ```
@MainActor
final class SettingsService: ObservableObject {

    /// Shared singleton instance
    static let shared = SettingsService()

    /// Current application settings
    @Published private(set) var settings: AppSettings = AppSettings()

    /// Directory containing the settings file
    private let configDirectory: URL

    /// Full path to the settings file
    private let settingsFileURL: URL

    // MARK: - Initialization

    private init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        configDirectory = homeDir
            .appendingPathComponent(".config")
            .appendingPathComponent("bep")
        settingsFileURL = configDirectory.appendingPathComponent("settings.toml")

        loadSettings()
    }

    // MARK: - Public Methods

    /// Updates settings using a closure and saves to disk.
    ///
    /// Example:
    /// ```swift
    /// SettingsService.shared.update { settings in
    ///     settings.frecencyRows = 3
    /// }
    /// ```
    func update(_ block: (inout AppSettings) -> Void) {
        block(&settings)
        saveSettings()
    }

    /// Reloads settings from disk, discarding any unsaved changes.
    func reload() {
        loadSettings()
    }

    // MARK: - Private Methods

    /// Loads settings from the TOML file, creating defaults if needed.
    private func loadSettings() {
        // Ensure config directory exists
        createConfigDirectoryIfNeeded()

        // Check if settings file exists
        guard FileManager.default.fileExists(atPath: settingsFileURL.path) else {
            // First run - create default settings file
            print("📁 BEP: No settings file found, creating defaults at \(settingsFileURL.path)")
            saveSettings()
            return
        }

        // Load and parse TOML
        do {
            let tomlString = try String(contentsOf: settingsFileURL, encoding: .utf8)
            let table = try TOMLTable(string: tomlString)
            settings = try TOMLDecoder().decode(AppSettings.self, from: table)
            print("✅ BEP: Loaded settings from \(settingsFileURL.path)")
        } catch {
            print("⚠️ BEP: Failed to load settings, using defaults: \(error)")
            // Keep default settings but don't overwrite potentially corrupted file
        }
    }

    /// Saves current settings to the TOML file.
    private func saveSettings() {
        createConfigDirectoryIfNeeded()

        do {
            let tomlString = try TOMLEncoder().encode(settings)

            // Add a header comment
            let fileContent = """
            # BEP (Better Emoji Picker) Settings
            # Edit this file to customize BEP behavior.
            # Changes take effect after restarting BEP.

            \(tomlString)
            """

            try fileContent.write(to: settingsFileURL, atomically: true, encoding: String.Encoding.utf8)
            print("💾 BEP: Saved settings to \(settingsFileURL.path)")
        } catch {
            print("❌ BEP: Failed to save settings: \(error)")
        }
    }

    /// Creates the config directory if it doesn't exist.
    private func createConfigDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(
                at: configDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            print("❌ BEP: Failed to create config directory: \(error)")
        }
    }
}
