//
//  EmojiStore.swift
//  BetterEmojiPicker
//
//  The main service for loading, searching, and tracking emoji usage.
//  Implements usage-based frecency: scores decay on each use, not by time.
//

import Foundation

/// Production implementation of EmojiStoreProtocol.
///
/// Frecency Algorithm:
/// On each emoji use:
///   1. Decay ALL emoji scores by factor 0.95
///   2. Boost the used emoji's score by +1.0
///   3. Clean up scores < 0.001 to prevent bloat
///
/// This naturally surfaces both frequently AND recently used emojis.
/// If you don't use the app, nothing decays (fair to inactive users).
@MainActor
final class EmojiStore: ObservableObject, EmojiStoreProtocol {

    @Published private(set) var allEmojis: [Emoji] = []
    @Published private(set) var recentEmojis: [Emoji] = []
    @Published private(set) var frequentEmojis: [Emoji] = []

    /// Frecency scores: emoji character → score
    private var frecencyScores: [String: Float] = [:]

    /// Decay factor applied to all scores on each use (0.95 = 5% decay per use)
    private let decayFactor: Float = 0.95

    /// Minimum score to keep (prevents dictionary bloat)
    private let minScore: Float = 0.001

    /// Maximum emojis to show in Recent section (configurable via settings)
    private var maxRecentCount: Int {
        SettingsService.shared.settings.frecencyRows * 10  // 10 columns per row
    }

    private enum StorageKeys {
        static let frecencyScores = "BEP_FrecencyScores"
        // Legacy keys for migration
        static let legacyRecentEmojis = "BEP_RecentEmojis"
        static let legacyUsageCounts = "BEP_UsageCounts"
        static let migrationComplete = "BEP_MigrationV2Complete"
    }

    init() {
        loadEmojisFromBundle()
        migrateIfNeeded()
        restoreFrecencyData()
    }

    // MARK: - Search

    func search(query: String) -> [Emoji] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return allEmojis }

        return allEmojis
            .map { emoji in (emoji: emoji, score: emoji.searchScore(for: trimmedQuery)) }
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
            .map { $0.emoji }
    }

    // MARK: - Usage Tracking

    func recordUsage(of emoji: Emoji) {
        // 1. Decay ALL scores
        for key in frecencyScores.keys {
            frecencyScores[key]! *= decayFactor
        }

        // 2. Boost the used emoji
        frecencyScores[emoji.emoji, default: 0] += 1.0

        // 3. Clean up very small scores to prevent unbounded growth
        frecencyScores = frecencyScores.filter { $0.value >= minScore }

        // 4. Update the recentEmojis list from scores
        updateRecentFromScores()

        // 5. Persist
        persistFrecencyData()
    }

    func clearFrecencyData() {
        frecencyScores = [:]
        recentEmojis = []
        frequentEmojis = []
        persistFrecencyData()
        print("🗑️ BEP: Cleared frecency data")
    }

    // MARK: - Private Methods

    private func loadEmojisFromBundle() {
        guard let url = Bundle.main.url(forResource: "emojis", withExtension: "json") else {
            print("⚠️ EmojiStore: Could not find emojis.json in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            allEmojis = try JSONDecoder().decode([Emoji].self, from: data)
            print("✅ EmojiStore: Loaded \(allEmojis.count) emojis")
        } catch {
            print("⚠️ EmojiStore: Failed to decode emojis.json: \(error)")
        }
    }

    /// Updates the recentEmojis array from frecency scores.
    private func updateRecentFromScores() {
        recentEmojis = frecencyScores
            .sorted { $0.value > $1.value }
            .prefix(maxRecentCount)
            .compactMap { emojiChar, _ in allEmojis.first { $0.emoji == emojiChar } }

        // frequentEmojis is the same as recentEmojis in the new model
        frequentEmojis = recentEmojis
    }

    // MARK: - Persistence

    private func persistFrecencyData() {
        let defaults = UserDefaults.standard

        // Encode scores as JSON
        if let encoded = try? JSONEncoder().encode(frecencyScores) {
            defaults.set(encoded, forKey: StorageKeys.frecencyScores)
        }
    }

    private func restoreFrecencyData() {
        let defaults = UserDefaults.standard

        if let data = defaults.data(forKey: StorageKeys.frecencyScores),
           let scores = try? JSONDecoder().decode([String: Float].self, from: data) {
            frecencyScores = scores
            updateRecentFromScores()
            print("✅ EmojiStore: Restored \(frecencyScores.count) frecency scores")
        }
    }

    // MARK: - Migration

    /// Migrates from legacy format (separate recent list + counts) to new frecency scores.
    private func migrateIfNeeded() {
        let defaults = UserDefaults.standard

        // Check if already migrated
        guard !defaults.bool(forKey: StorageKeys.migrationComplete) else { return }

        // Check if there's legacy data to migrate
        let hasLegacyRecent = defaults.array(forKey: StorageKeys.legacyRecentEmojis) != nil
        let hasLegacyCounts = defaults.dictionary(forKey: StorageKeys.legacyUsageCounts) != nil

        guard hasLegacyRecent || hasLegacyCounts else {
            // No legacy data, mark as complete
            defaults.set(true, forKey: StorageKeys.migrationComplete)
            return
        }

        print("🔄 BEP: Migrating legacy frecency data...")

        var newScores: [String: Float] = [:]

        // 1. Convert usage counts to initial scores
        if let oldCounts = defaults.dictionary(forKey: StorageKeys.legacyUsageCounts) as? [String: Int] {
            let maxCount = Float(oldCounts.values.max() ?? 1)
            for (emoji, count) in oldCounts {
                // Scale to 0-10 range based on relative frequency
                newScores[emoji] = Float(count) / maxCount * 10.0
            }
        }

        // 2. Apply recency bonus from old recent list order
        if let recentChars = defaults.array(forKey: StorageKeys.legacyRecentEmojis) as? [String] {
            for (index, emoji) in recentChars.enumerated() {
                // More recent = higher bonus (0.1 per position from end)
                let recencyBonus = Float(recentChars.count - index) * 0.1
                newScores[emoji, default: 0] += recencyBonus
            }
        }

        // 3. Store new format
        frecencyScores = newScores
        persistFrecencyData()

        // 4. Mark migration complete (keep old data as backup)
        defaults.set(true, forKey: StorageKeys.migrationComplete)

        print("✅ BEP: Migrated \(newScores.count) emoji scores")
    }
}
