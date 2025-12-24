//
//  EmojiCategory.swift
//  BetterEmojiPicker
//
//  Defines the standard emoji categories for organization and display.
//

import Foundation

/// Standard Unicode emoji categories.
enum EmojiCategory: String, CaseIterable, Codable {
    case smileysAndEmotion = "Smileys & Emotion"
    case peopleAndBody = "People & Body"
    case animalsAndNature = "Animals & Nature"
    case foodAndDrink = "Food & Drink"
    case travelAndPlaces = "Travel & Places"
    case activities = "Activities"
    case objects = "Objects"
    case symbols = "Symbols"
    case flags = "Flags"

    var displayName: String { rawValue }

    var iconName: String {
        switch self {
        case .smileysAndEmotion: return "face.smiling"
        case .peopleAndBody: return "person"
        case .animalsAndNature: return "leaf"
        case .foodAndDrink: return "fork.knife"
        case .travelAndPlaces: return "car"
        case .activities: return "sportscourt"
        case .objects: return "lightbulb"
        case .symbols: return "number"
        case .flags: return "flag"
        }
    }
}
