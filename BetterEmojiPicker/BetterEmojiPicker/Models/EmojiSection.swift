//
//  EmojiSection.swift
//  BetterEmojiPicker
//
//  Represents a section of emojis for display (e.g., "Recent", "Smileys & Emotion").
//

import Foundation

/// A section of emojis with a title and list of emojis.
struct EmojiSection: Identifiable, Equatable {
    let id: String
    let title: String
    let emojis: [Emoji]

    static func == (lhs: EmojiSection, rhs: EmojiSection) -> Bool {
        lhs.id == rhs.id && lhs.emojis.map(\.emoji) == rhs.emojis.map(\.emoji)
    }
}
