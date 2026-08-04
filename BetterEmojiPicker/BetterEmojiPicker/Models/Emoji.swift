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

    /// The primary name of the emoji (e.g., "thumbs up")
    ///
    /// This is the CLDR display name, not the legacy Unicode character name.
    /// The legacy name lives in `keywords` so older queries still resolve.
    let name: String

    /// Additional searchable terms (e.g., ["happy", "smile", "joy"])
    let keywords: [String]

    /// The category this emoji belongs to (e.g., "Smileys & Emotion")
    let category: String

    /// Unicode Consortium sort order. Lower values = more canonical/common emojis.
    /// Used as a final tiebreaker in search ranking.
    let sortOrder: Int

    /// How likely a user is to want this emoji, from 0 to 1.
    ///
    /// A ranking prior rather than a measurement: it blends observed usage
    /// frequency with a penalty for non-canonical forms (gendered, directional,
    /// and hair variants; flags). Built by `Scripts/build_emoji_data.py`.
    let popularity: Float

    /// Use the emoji character itself as the unique identifier.
    var id: String { emoji }

    init(emoji: String, name: String, keywords: [String] = [], category: String = "Other",
         sortOrder: Int = 9999, popularity: Float = Emoji.defaultPopularity) {
        self.emoji = emoji
        self.name = name
        self.keywords = keywords
        self.category = category
        self.sortOrder = sortOrder
        self.popularity = popularity
    }

    /// Applied when the bundled data predates the `popularity` field.
    /// Matches the no-data default in the build script.
    static let defaultPopularity: Float = 0.3

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        emoji = try container.decode(String.self, forKey: .emoji)
        name = try container.decode(String.self, forKey: .name)
        keywords = try container.decodeIfPresent([String].self, forKey: .keywords) ?? []
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "Other"
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 9999
        // Tolerated rather than required: a stale bundled emojis.json should
        // degrade ranking, not leave the picker empty.
        popularity = try container.decodeIfPresent(Float.self, forKey: .popularity) ?? Emoji.defaultPopularity
    }
}

// MARK: - Search Support

extension Emoji {

    /// How well a single query word matches, from best to worst.
    ///
    /// Raw values are the tier's contribution to the score. The gaps matter
    /// more than the absolute numbers: a better tier must always win, because
    /// no amount of popularity should surface a worse match.
    private enum MatchTier: Int {
        case exactName = 150
        case exactKeyword = 120
        case namePrefix = 100
        case wordInName = 90
        case nameWordPrefix = 70
        case keywordPrefix = 55
        case substring = 20
    }

    /// Weight applied to match tier. Larger than every other term combined, so
    /// tiers never blend into each other.
    private static let tierWeight = 10_000

    /// Weight applied to the fraction of the emoji's name the query covers.
    private static let coverageWeight = 2_500

    /// Weight applied to popularity. Enough to reorder freely within a tier.
    private static let popularityWeight = 6_000

    /// Largest nudge from Unicode sort order. Small next to the other terms,
    /// but it does most of its work among the ~1000 emoji that share the
    /// default popularity and would otherwise tie outright.
    private static let sortOrderNudgeMax = 300

    /// Sort orders above this get no nudge at all.
    private static let sortOrderNudgeRange = 2000

    /// Calculates a relevance score for this emoji given a search query.
    /// Higher scores indicate better matches. Zero means no match.
    ///
    /// Four factors, in descending influence:
    /// 1. Match tier - how directly the query hits the name or keywords
    /// 2. Popularity - which of several equally-good matches people actually use
    /// 3. Name coverage - how much of the emoji's name the query accounts for
    /// 4. Unicode sort order - a nudge to break exact ties deterministically
    ///
    /// Coverage is deliberately a *ratio*, not a count of unmatched words. A raw
    /// count penalizes long names, and the legacy Unicode names were longest for
    /// precisely the emoji people search for most ("person with folded hands"
    /// for 🙏), which inverted relevance.
    func searchScore(for query: String) -> Int {
        let queryWords = Self.words(in: query)
        guard !queryWords.isEmpty else { return 0 }

        let nameLower = name.lowercased()
        let nameWords = Self.words(in: nameLower)
        let keywordsLower = keywords.map { $0.lowercased() }

        // Every query word must match something, or this emoji is not a result.
        var tierTotal = 0
        for word in queryWords {
            guard let tier = matchTier(for: word, nameLower: nameLower,
                                       nameWords: nameWords, keywords: keywordsLower) else {
                return 0
            }
            tierTotal += tier.rawValue
        }

        // Average rather than sum, so a two-word loose match cannot outrank a
        // one-word exact match purely by having more words.
        let averageTier = tierTotal / queryWords.count

        let matchedNameWords = nameWords.filter { nameWord in
            queryWords.contains { nameWord.hasPrefix($0) || $0.hasPrefix(nameWord) }
        }.count
        let coverage = nameWords.isEmpty ? 0 : Float(matchedNameWords) / Float(nameWords.count)

        let sortOrderNudge = max(0, Self.sortOrderNudgeRange - sortOrder)
            * Self.sortOrderNudgeMax / Self.sortOrderNudgeRange

        return averageTier * Self.tierWeight
            + Int(coverage * Float(Self.coverageWeight))
            + Int(popularity * Float(Self.popularityWeight))
            + sortOrderNudge
    }

    private func matchTier(for word: String, nameLower: String, nameWords: [String],
                           keywords: [String]) -> MatchTier? {
        if nameLower == word { return .exactName }
        if keywords.contains(word) { return .exactKeyword }
        if nameLower.hasPrefix(word) { return .namePrefix }
        if nameWords.contains(word) { return .wordInName }
        if nameWords.contains(where: { $0.hasPrefix(word) }) { return .nameWordPrefix }
        if keywords.contains(where: { $0.hasPrefix(word) }) { return .keywordPrefix }
        // Checked per-field rather than against a joined string. A query word
        // never contains whitespace, so it can never span a join separator -
        // the results are identical and this avoids allocating on the hot path,
        // which every non-matching emoji reaches.
        if nameLower.contains(word) { return .substring }
        if keywords.contains(where: { $0.contains(word) }) { return .substring }
        return nil
    }

    private static func words(in text: String) -> [String] {
        text.lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
    }
}
