//
//  EmojiStore.swift
//  BetterEmojiPicker
//
//  The main service for loading, searching, and tracking emoji usage.
//

import Foundation

/// Production implementation of EmojiStoreProtocol.
@MainActor
final class EmojiStore: ObservableObject, EmojiStoreProtocol {

    @Published private(set) var allEmojis: [Emoji] = []
    @Published private(set) var recentEmojis: [Emoji] = []
    @Published private(set) var frequentEmojis: [Emoji] = []

    private var usageCounts: [String: Int] = [:]
    private let maxRecentCount = 20
    private let maxFrequentCount = 20

    private enum StorageKeys {
        static let recentEmojis = "BEP_RecentEmojis"
        static let usageCounts = "BEP_UsageCounts"
    }

    init() {
        loadEmojisFromBundle()
        restoreUsageData()
    }

    func search(query: String) -> [Emoji] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return allEmojis }

        return allEmojis
            .map { emoji in (emoji: emoji, score: emoji.searchScore(for: trimmedQuery)) }
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
            .map { $0.emoji }
    }

    func recordUsage(of emoji: Emoji) {
        updateRecent(emoji)
        updateFrequency(emoji)
        persistUsageData()
    }

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

    private func updateRecent(_ emoji: Emoji) {
        recentEmojis.removeAll { $0.emoji == emoji.emoji }
        recentEmojis.insert(emoji, at: 0)
        if recentEmojis.count > maxRecentCount {
            recentEmojis = Array(recentEmojis.prefix(maxRecentCount))
        }
    }

    private func updateFrequency(_ emoji: Emoji) {
        usageCounts[emoji.emoji, default: 0] += 1
        frequentEmojis = usageCounts
            .sorted { $0.value > $1.value }
            .prefix(maxFrequentCount)
            .compactMap { emojiChar, _ in allEmojis.first { $0.emoji == emojiChar } }
    }

    private func persistUsageData() {
        let defaults = UserDefaults.standard
        defaults.set(recentEmojis.map { $0.emoji }, forKey: StorageKeys.recentEmojis)
        defaults.set(usageCounts, forKey: StorageKeys.usageCounts)
    }

    private func restoreUsageData() {
        let defaults = UserDefaults.standard

        if let recentChars = defaults.array(forKey: StorageKeys.recentEmojis) as? [String] {
            recentEmojis = recentChars.compactMap { char in allEmojis.first { $0.emoji == char } }
        }

        if let counts = defaults.dictionary(forKey: StorageKeys.usageCounts) as? [String: Int] {
            usageCounts = counts
            frequentEmojis = usageCounts
                .sorted { $0.value > $1.value }
                .prefix(maxFrequentCount)
                .compactMap { emojiChar, _ in allEmojis.first { $0.emoji == emojiChar } }
        }
    }
}
