//
//  PickerViewModel.swift
//  BetterEmojiPicker
//
//  The ViewModel managing the emoji picker's state and user interactions.
//

import Foundation
import SwiftUI
import Combine

/// Manages the state and logic for the emoji picker interface.
@MainActor
final class PickerViewModel: ObservableObject {

    @Published var searchQuery: String = ""
    @Published private(set) var displayedEmojis: [Emoji] = []
    @Published private(set) var sections: [EmojiSection] = []
    @Published var selectedIndex: Int? = nil
    @Published var isVisible: Bool = false
    @Published private(set) var sectionTitle: String = "Recent"

    private let emojiStore: EmojiStoreProtocol
    private var cancellables = Set<AnyCancellable>()

    let gridColumns = 10

    init(emojiStore: EmojiStoreProtocol) {
        self.emojiStore = emojiStore
        setupSearchDebounce()
        updateDisplayedEmojis()
    }

    private func setupSearchDebounce() {
        $searchQuery
            .removeDuplicates()
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateDisplayedEmojis() }
            .store(in: &cancellables)
    }

    private func updateDisplayedEmojis() {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedQuery.isEmpty {
            // Build sections: Recent + all categories
            var newSections: [EmojiSection] = []
            var flatEmojis: [Emoji] = []

            // Recent section (frecency-based)
            if !emojiStore.recentEmojis.isEmpty {
                newSections.append(EmojiSection(
                    id: "recent",
                    title: "Recent",
                    emojis: emojiStore.recentEmojis
                ))
                flatEmojis.append(contentsOf: emojiStore.recentEmojis)
            }

            // Group all emojis by category (category is a String in Emoji model)
            let grouped = Dictionary(grouping: emojiStore.allEmojis, by: { $0.category })
            for category in EmojiCategory.allCases {
                // Match by rawValue since Emoji.category is a String
                if let categoryEmojis = grouped[category.rawValue], !categoryEmojis.isEmpty {
                    // Sort by Unicode Consortium sortOrder (yellow faces first, etc.)
                    let sortedEmojis = categoryEmojis.sorted { $0.sortOrder < $1.sortOrder }
                    newSections.append(EmojiSection(
                        id: category.rawValue,
                        title: category.displayName,
                        emojis: sortedEmojis
                    ))
                    flatEmojis.append(contentsOf: sortedEmojis)
                }
            }

            sections = newSections
            displayedEmojis = flatEmojis
            sectionTitle = "Recent" // Legacy, not really used anymore
        } else {
            // Search mode: single section with results
            let searchResults = emojiStore.search(query: trimmedQuery)
            sections = [EmojiSection(
                id: "results",
                title: searchResults.isEmpty ? "No Results" : "Search Results",
                emojis: searchResults
            )]
            displayedEmojis = searchResults
            sectionTitle = searchResults.isEmpty ? "No Results" : "Search Results"
        }

        selectedIndex = displayedEmojis.isEmpty ? nil : 0
    }

    func moveUp() {
        guard let current = selectedIndex, !displayedEmojis.isEmpty else { selectedIndex = 0; return }
        let newIndex = current - gridColumns
        if newIndex >= 0 { selectedIndex = newIndex }
    }

    func moveDown() {
        guard let current = selectedIndex, !displayedEmojis.isEmpty else { selectedIndex = 0; return }
        let newIndex = current + gridColumns
        if newIndex < displayedEmojis.count { selectedIndex = newIndex }
    }

    func moveLeft() {
        guard let current = selectedIndex, !displayedEmojis.isEmpty else { selectedIndex = 0; return }
        if current > 0 { selectedIndex = current - 1 }
    }

    func moveRight() {
        guard let current = selectedIndex, !displayedEmojis.isEmpty else { selectedIndex = 0; return }
        if current < displayedEmojis.count - 1 { selectedIndex = current + 1 }
    }

    var selectedEmoji: Emoji? {
        guard let index = selectedIndex, index < displayedEmojis.count else { return nil }
        return displayedEmojis[index]
    }

    func confirmSelection() -> Emoji? {
        guard let emoji = selectedEmoji else { return nil }
        emojiStore.recordUsage(of: emoji)
        if searchQuery.isEmpty { updateDisplayedEmojis() }
        return emoji
    }

    func selectEmoji(_ emoji: Emoji) -> Emoji {
        if let index = displayedEmojis.firstIndex(of: emoji) { selectedIndex = index }
        emojiStore.recordUsage(of: emoji)
        if searchQuery.isEmpty { updateDisplayedEmojis() }
        return emoji
    }

    func onShow() {
        isVisible = true
        searchQuery = ""
        updateDisplayedEmojis()
    }

    func onHide() {
        isVisible = false
    }

    /// Records usage of an emoji without any selection or insertion logic.
    /// Used for copy-to-clipboard operations.
    func recordUsage(of emoji: Emoji) {
        emojiStore.recordUsage(of: emoji)
        if searchQuery.isEmpty { updateDisplayedEmojis() }
    }
}
