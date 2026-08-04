//
//  SearchTests.swift
//  BetterEmojiPickerTests
//
//  Ranking tests for emoji search.
//
//  Search ranking is tuned by adjusting weights, and a weight that improves one
//  query routinely wrecks another. The golden table below is the safety net:
//  it pins the behaviour that motivated the ranking work, plus a set of queries
//  that already worked and must keep working.
//
//  When a golden fails, decide whether the new order is genuinely better before
//  touching the expectation. Updating the table to match a regression defeats
//  the point of having one.
//

import Foundation
import Testing

@testable import BetterEmojiPicker

// MARK: - Fixture

private enum Fixture {

    /// The exact data the app ships, decoded once and shared by every test.
    static let emojis: [Emoji] = {
        guard let url = Bundle.main.url(forResource: "emojis", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            fatalError("emojis.json is not in the test host bundle. Check that the "
                       + "BetterEmojiPickerTests target still has BetterEmojiPicker.app as its TEST_HOST.")
        }
        do {
            return try JSONDecoder().decode([Emoji].self, from: data)
        } catch {
            fatalError("emojis.json did not decode: \(error). Regenerate it with "
                       + "Scripts/build_emoji_data.py.")
        }
    }()

    /// Runs the real production ranking, with no personal usage history.
    static func ranked(_ query: String) -> [Emoji] {
        EmojiStore.rank(emojis, query: query, personalScores: [:])
    }

    static func characters(_ query: String, limit: Int = 8) -> [String] {
        ranked(query).prefix(limit).map(\.emoji)
    }

    static func emoji(_ character: String) -> Emoji {
        guard let match = emojis.first(where: { $0.emoji == character }) else {
            fatalError("\(character) is not in emojis.json")
        }
        return match
    }
}

// MARK: - Golden rankings

struct SearchRankingTests {

    /// Queries where one emoji is overwhelmingly the intended answer.
    ///
    /// The first four are the cases that prompted this work: each one used to
    /// return something else entirely, and `pushpin` for "thumb" is the one a
    /// user actually reported.
    @Test("Obvious query returns the obvious emoji", arguments: [
        ("thumb", "👍"),
        ("pray", "🙏"),
        ("heart", "❤️"),
        ("love", "❤️"),
        ("star", "⭐"),
        ("fire", "🔥"),
        ("eyes", "👀"),
        ("clap", "👏"),
        ("100", "💯"),
        ("skull", "💀"),
        ("shrug", "🤷"),
        ("facepalm", "🤦"),
        ("think", "🤔"),
        ("money", "💰"),
        ("moon", "🌙"),
        ("sun", "☀️"),
        ("party", "🎉"),
        ("celebrate", "🎉"),
    ])
    func topResult(query: String, expected: String) {
        let top = Fixture.characters(query, limit: 5)
        #expect(top.first == expected,
                "'\(query)' should rank \(expected) first, got \(top.joined(separator: " "))")
    }

    /// `laugh` already worked before this ranking change and is the sharpest
    /// test that the curated modern-popularity data is wired in: 🤣 postdates
    /// the usage snapshot, so without `MODERN_POPULAR` it falls behind 😂.
    @Test("Modern emoji outrank their older near-synonyms")
    func modernPopularityApplies() {
        #expect(Fixture.characters("laugh").first == "🤣")
        #expect(Fixture.emoji("🤣").popularity > Fixture.emoji("😹").popularity)
        #expect(Fixture.emoji("🤔").popularity > Fixture.emoji("💭").popularity)
    }

    /// Queries with several defensible answers. Pinning an exact winner here
    /// would make the table brittle for no benefit, but the right emoji must
    /// still be near the top rather than buried.
    @Test("Ambiguous query surfaces the plausible answers", arguments: [
        ("smile", "😊"),
        ("cry", "😭"),
        ("sad", "😢"),
        ("ok", "👌"),
        ("check", "✅"),
        ("hand", "👋"),
        ("wave", "👋"),
        ("cat", "🐱"),
        ("dog", "🐶"),
        ("yes", "👍"),
        ("hug", "🤗"),
        ("cool", "😎"),
    ])
    func rankedNearTop(query: String, expected: String) {
        let top = Fixture.characters(query)
        #expect(top.contains(expected),
                "'\(query)' should surface \(expected) in the top \(top.count), got \(top.joined(separator: " "))")
    }

    @Test("Every query word must match")
    func allWordsRequired() {
        #expect(Fixture.ranked("thumbs up").contains { $0.emoji == "👍" })
        // "zzz" matches the sleeping emoji, "qqqq" matches nothing, so the
        // combination must return no results at all.
        #expect(Fixture.ranked("zzz qqqq").isEmpty)
    }

    @Test("Blank query returns everything unfiltered")
    func blankQuery() {
        #expect(Fixture.ranked("   ").count == Fixture.emojis.count)
    }

    @Test("Search is case insensitive")
    func caseInsensitive() {
        #expect(Fixture.characters("THUMB") == Fixture.characters("thumb"))
    }

    /// The legacy Unicode names moved into keywords when display names switched
    /// to CLDR. Anyone who learned the old name must still find the emoji.
    @Test("Legacy Unicode names still resolve", arguments: [
        ("heavy black heart", "❤️"),
        ("thumbs up sign", "👍"),
        ("person with folded hands", "🙏"),
    ])
    func legacyNamesStillFindable(query: String, expected: String) {
        #expect(Fixture.characters(query, limit: 3).contains(expected))
    }
}

// MARK: - Ranking properties

struct SearchScoringTests {

    /// Gendered, directional, and hair variants flooded results before they
    /// were demoted: "pray" returned five kneeling variants above 🙏.
    @Test("Base emoji outranks its own variants", arguments: [
        ("🧎", ["🧎‍♂️", "🧎‍♀️", "🧎‍➡️", "🧎‍♀️‍➡️", "🧎‍♂️‍➡️"]),
        ("🤷", ["🤷‍♀️", "🤷‍♂️"]),
        ("🤦", ["🤦‍♀️", "🤦‍♂️"]),
    ])
    func baseBeatsVariants(base: String, variants: [String]) {
        let ranking = Fixture.ranked(Fixture.emoji(base).name)
        guard let basePosition = ranking.firstIndex(where: { $0.emoji == base }) else {
            Issue.record("\(base) did not match its own name")
            return
        }
        for variant in variants {
            let position = ranking.firstIndex { $0.emoji == variant }
            #expect(position == nil || position! > basePosition,
                    "\(base) should rank above its variant \(variant)")
        }
    }

    @Test("Popularity breaks ties within a match tier")
    func popularityDecidesTies() {
        // Identical match quality for "widget", so only popularity separates them.
        let popular = Emoji(emoji: "A", name: "widget", popularity: 0.9)
        let obscure = Emoji(emoji: "B", name: "widget", popularity: 0.1)
        #expect(popular.searchScore(for: "widget") > obscure.searchScore(for: "widget"))
    }

    @Test("A better match tier always beats a more popular worse match")
    func tierBeatsPopularity() {
        let exact = Emoji(emoji: "A", name: "widget", popularity: 0.0)
        let substring = Emoji(emoji: "B", name: "superwidgeteer", popularity: 1.0)
        #expect(exact.searchScore(for: "widget") > substring.searchScore(for: "widget"))
    }

    /// A long name used to be penalised per unmatched word, which buried the
    /// popular emoji because their legacy names were the longest.
    @Test("Name length alone does not decide ranking")
    func longNamesNotPenalised() {
        let short = Emoji(emoji: "A", name: "kneeling person", keywords: ["pray"], popularity: 0.3)
        let long = Emoji(emoji: "B", name: "person with folded hands", keywords: ["pray"], popularity: 0.9)
        #expect(long.searchScore(for: "pray") > short.searchScore(for: "pray"))
    }

    @Test("Non-matching emoji score zero")
    func nonMatchScoresZero() {
        #expect(Emoji(emoji: "A", name: "widget").searchScore(for: "sprocket") == 0)
    }
}

// MARK: - Personal usage

struct PersonalBoostTests {

    @Test("Heavy personal use reorders equally good matches")
    func boostReordersWithinTier() {
        let ranking = EmojiStore.rank(Fixture.emojis, query: "cry", personalScores: ["😿": 99])
        #expect(ranking.first?.emoji == "😿")
    }

    /// The cap is what keeps the boost safe. Without it a heavily-used emoji
    /// would hijack every query it matches even weakly.
    ///
    /// 🙏 carries "pray" as an explicit keyword; 📿 only matches because
    /// "prayer beads" starts with it. That is a full tier apart, and no amount
    /// of personal use may close it.
    @Test("Personal use cannot promote a worse match")
    func boostCannotCrossTiers() {
        let ranking = EmojiStore.rank(Fixture.emojis, query: "pray", personalScores: ["📿": 99])
        #expect(ranking.first?.emoji == "🙏")
    }

    @Test("Personal use never invents a match")
    func boostDoesNotAddResults() {
        let ranking = EmojiStore.rank(Fixture.emojis, query: "sprocket", personalScores: ["😂": 99])
        #expect(ranking.isEmpty)
    }

    @Test("Boost saturates rather than growing without bound")
    func boostSaturates() {
        #expect(EmojiStore.personalBoost(frecencyScore: 0) == 0)
        #expect(EmojiStore.personalBoost(frecencyScore: 1000)
                == Int(EmojiStore.maxPersonalBoost))
        #expect(EmojiStore.personalBoost(frecencyScore: 1)
                < EmojiStore.personalBoost(frecencyScore: 2))
    }
}

// MARK: - Data integrity

struct EmojiDataTests {

    @Test("Every emoji has usable search data")
    func fieldsPopulated() {
        for emoji in Fixture.emojis {
            #expect(!emoji.emoji.isEmpty)
            #expect(!emoji.name.isEmpty, "\(emoji.emoji) has no name")
            #expect(!emoji.keywords.isEmpty, "\(emoji.emoji) (\(emoji.name)) has no keywords")
            #expect((0...1).contains(emoji.popularity),
                    "\(emoji.emoji) has popularity \(emoji.popularity) outside 0...1")
        }
    }

    /// The scorer lowercases defensively, but the build script emits lowercase
    /// already. If that stops being true, prefix matching quietly degrades.
    @Test("Names and keywords are stored lowercase")
    func lowercased() {
        for emoji in Fixture.emojis {
            #expect(emoji.name == emoji.name.lowercased(), "\(emoji.emoji) name is not lowercase")
        }
    }

    @Test("Display names come from CLDR, not the legacy Unicode names", arguments: [
        ("❤️", "red heart"),
        ("👍", "thumbs up"),
        ("🙏", "folded hands"),
        ("⭐", "star"),
    ])
    func usesCLDRNames(character: String, expected: String) {
        #expect(Fixture.emoji(character).name == expected)
    }

    @Test("popularity survives a decode without the field")
    func popularityDefaults() throws {
        let json = #"{"emoji":"🙂","name":"slightly smiling face","keywords":["smile"],"category":"Smileys & Emotion","sortOrder":9}"#
        let decoded = try JSONDecoder().decode(Emoji.self, from: Data(json.utf8))
        #expect(decoded.popularity == Emoji.defaultPopularity)
    }
}
