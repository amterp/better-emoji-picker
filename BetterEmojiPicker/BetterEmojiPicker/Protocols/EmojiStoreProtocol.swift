//
//  EmojiStoreProtocol.swift
//  BetterEmojiPicker
//
//  Protocol defining the interface for emoji data access.
//

import Foundation

/// Protocol for emoji data access and search.
@MainActor
protocol EmojiStoreProtocol {
    var allEmojis: [Emoji] { get }
    var recentEmojis: [Emoji] { get }
    var frequentEmojis: [Emoji] { get }
    func search(query: String) -> [Emoji]
    func recordUsage(of emoji: Emoji)
}
