//
//  AppSettings.swift
//  BetterEmojiPicker
//
//  User-configurable application settings.
//  Stored as TOML at ~/.config/bep/settings.toml
//

import Foundation

/// Application settings that persist across sessions.
///
/// These are user preferences (sync-friendly, git-manageable) as opposed to
/// machine-local data like frecency scores which stay in UserDefaults.
struct AppSettings: Codable, Equatable {

    /// Number of rows to show in the Recent section (1-5)
    var frecencyRows: Int = 2

    /// Delay in milliseconds before restoring clipboard after paste (50-1000)
    var clipboardRestoreDelay: Int = 200

    /// Whether the user has completed the onboarding wizard
    var onboardingCompleted: Bool = false

    // MARK: - TOML Keys

    /// Maps Swift property names to TOML keys (snake_case for readability)
    enum CodingKeys: String, CodingKey {
        case frecencyRows = "frecency_rows"
        case clipboardRestoreDelay = "clipboard_restore_delay"
        case onboardingCompleted = "onboarding_completed"
    }
}
