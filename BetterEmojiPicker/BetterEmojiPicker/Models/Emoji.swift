//
//  Emoji.swift
//  BetterEmojiPicker
//
//  The core data model representing a single emoji with its searchable metadata.
//

import Foundation

/// Represents a single emoji with its associated metadata for display and search.
struct Emoji: Codable, Identifiable, Hashable, Equatable {

    /// The emoji character itself (e.g., "😀")
    let emoji: String

    /// The primary name of the emoji (e.g., "grinning face")
    let name: String

    /// Additional searchable terms (e.g., ["happy", "smile", "joy"])
    let keywords: [String]

    /// The category this emoji belongs to (e.g., "Smileys & Emotion")
    let category: String

    /// Unicode Consortium sort order. Lower values = more canonical/common emojis.
    /// Used as a tiebreaker in search ranking.
    let sortOrder: Int

    /// Use the emoji character itself as the unique identifier.
    var id: String { emoji }

    init(emoji: String, name: String, keywords: [String] = [], category: String = "Other", sortOrder: Int = 9999) {
        self.emoji = emoji
        self.name = name
        self.keywords = keywords
        self.category = category
        self.sortOrder = sortOrder
    }
}

// MARK: - Search Support

extension Emoji {

    /// All searchable text combined into a single lowercase string.
    var searchableText: String {
        ([name] + keywords).joined(separator: " ").lowercased()
    }

    /// Checks if this emoji matches a search query.
    func matches(query: String) -> Bool {
        let lowercasedQuery = query.lowercased()
        return searchableText.contains(lowercasedQuery)
    }

    /// Calculates a relevance score for this emoji given a search query.
    /// Higher scores indicate better matches.
    ///
    /// Uses a multi-factor scoring approach:
    /// 1. Match quality (primary) - How well does the query match name/keywords?
    /// 2. Specificity penalty - Penalize emojis with extra unmatched words (e.g., "cat" in "smiling cat face")
    /// 3. Unicode sort order (tiebreaker) - Earlier in Unicode = more canonical
    ///
    /// Key insight: Users search by concept (keywords like "happy", "smile"), not by
    /// technical Unicode names. So exact keyword matches should beat words buried in names.
    func searchScore(for query: String) -> Int {
        let queryLower = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !queryLower.isEmpty else { return 0 }

        let queryWords = queryLower.split(separator: " ").map(String.init)
        var matchScore = 0

        for word in queryWords {
            let wordScore = scoreForSingleWord(word)
            if wordScore == 0 { return 0 }  // All query words must match
            matchScore += wordScore
        }

        // Calculate unmatched word penalty.
        // Emojis with extra qualifying words (like "cat" in "smiling cat face") should rank
        // lower than direct matches (like "smiling face") when the query is just "smile".
        // This is the "noise" in the match - more noise = less relevant.
        let nameWords = name.lowercased().split(separator: " ").map(String.init)
        var unmatchedWords = 0
        for nameWord in nameWords {
            let isMatched = queryWords.contains { queryWord in
                nameWord.hasPrefix(queryWord) || queryWord.hasPrefix(nameWord)
            }
            if !isMatched {
                unmatchedWords += 1
            }
        }

        // Unicode sort order bonus: lower sortOrder = more canonical emoji.
        // sortOrder ranges roughly 0-2000, so we invert it to make lower values score higher.
        let orderBonus = max(0, 3000 - sortOrder)

        // Combine factors with balanced weights:
        // - matchScore: 0-150 per word, multiplied to be primary factor
        // - unmatchedWords: penalty of 5000 per extra word (substantial!)
        //   e.g., "cat face with wry smile" has 4 extra words = -20,000 points
        // - orderBonus: 0-3000, meaningful tiebreaker now that multipliers are balanced
        return matchScore * 1000 - unmatchedWords * 5000 + orderBonus
    }

    private func scoreForSingleWord(_ word: String) -> Int {
        let nameLower = name.lowercased()

        // 1. EXACT NAME MATCH (Highest priority)
        // e.g., "fire" matches emoji named "fire"
        if nameLower == word { return 150 }

        // 2. EXACT KEYWORD MATCH (High priority - BOOSTED)
        // Users think in keywords/concepts, not Unicode technical names.
        // "smile" as a keyword for 😀 should beat "smile" buried in "cat face with wry smile"
        for keyword in keywords {
            if keyword.lowercased() == word { return 100 }
        }

        // 3. NAME PREFIX MATCH (High priority)
        // e.g., "smil" matches "smiling face"
        if nameLower.hasPrefix(word) { return 95 }

        // 4. WORD IN NAME EXACT (Medium priority - REDUCED)
        // e.g., "smile" in "cat face with wry smile"
        // Lower than keyword because it's often incidental, not the emoji's core meaning
        let nameWords = nameLower.split(separator: " ").map(String.init)
        if nameWords.contains(word) { return 85 }

        // 5. WORD IN NAME PREFIX (Medium-low priority)
        // e.g., "cry" matches "crying" in "crying face"
        for nameWord in nameWords {
            if nameWord.hasPrefix(word) { return 75 }
        }

        // 6. KEYWORD PREFIX (Lower priority)
        // e.g., "smi" matches keyword "smile"
        for keyword in keywords {
            if keyword.lowercased().hasPrefix(word) { return 60 }
        }

        // 7. SUBSTRING MATCH (Lowest priority)
        // Fallback for partial matches anywhere
        if searchableText.contains(word) { return 20 }

        return 0
    }
}
