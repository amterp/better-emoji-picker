//
//  PickerViewModel.swift
//  BetterEmojiPicker
//
//  The ViewModel managing the emoji picker's state and user interactions.
//

import Foundation
import SwiftUI
import Combine

/// Represents a cell's position in the visual grid layout.
private struct GridPosition: Equatable {
    let flatIndex: Int          // Index in displayedEmojis
    let sectionIndex: Int       // Which section (0-based)
    let visualRow: Int          // Row in the overall visual grid (accounting for section breaks)
    let column: Int             // Column within the row (0 to columnCount-1)
}

/// Manages the state and logic for the emoji picker interface.
@MainActor
final class PickerViewModel: ObservableObject {

    @Published var searchQuery: String = ""
    @Published private(set) var displayedEmojis: [Emoji] = []
    @Published private(set) var sections: [EmojiSection] = []
    @Published var selectedIndex: Int? = nil
    @Published var isVisible: Bool = false
    @Published private(set) var sectionTitle: String = "Recent"
    @Published private(set) var scrollToTopTrigger: Int = 0

    private let emojiStore: EmojiStoreProtocol
    private var cancellables = Set<AnyCancellable>()

    let gridColumns = 10

    /// Maps flat index to grid position for navigation
    private var gridPositions: [GridPosition] = []
    /// Maps (visualRow, column) to flat index for reverse lookup
    private var gridLookup: [[Int?]] = []

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
        buildGridModel()
    }

    /// Builds the visual grid model for section-aware navigation.
    /// Each section starts on a new row, so we need to track visual positions separately from flat indices.
    private func buildGridModel() {
        gridPositions = []
        gridLookup = []

        guard !sections.isEmpty else { return }

        var flatIndex = 0
        var currentVisualRow = 0

        for (sectionIndex, section) in sections.enumerated() {
            // Process each emoji in this section
            for (indexInSection, _) in section.emojis.enumerated() {
                let column = indexInSection % gridColumns
                let rowInSection = indexInSection / gridColumns
                let visualRow = currentVisualRow + rowInSection

                // Ensure gridLookup has enough rows
                while gridLookup.count <= visualRow {
                    gridLookup.append(Array(repeating: nil, count: gridColumns))
                }

                let position = GridPosition(
                    flatIndex: flatIndex,
                    sectionIndex: sectionIndex,
                    visualRow: visualRow,
                    column: column
                )
                gridPositions.append(position)
                gridLookup[visualRow][column] = flatIndex

                flatIndex += 1
            }

            // Next section starts on a new visual row
            if !section.emojis.isEmpty {
                let rowsInSection = (section.emojis.count + gridColumns - 1) / gridColumns
                currentVisualRow += rowsInSection
            }
        }
    }

    func moveUp() {
        guard let current = selectedIndex,
              current < gridPositions.count,
              !displayedEmojis.isEmpty else {
            selectedIndex = 0
            return
        }

        let currentPos = gridPositions[current]

        // Try to find a cell directly above (same column, previous row)
        if currentPos.visualRow > 0 {
            // Look for a cell at (visualRow - 1, column)
            if let targetIndex = gridLookup[currentPos.visualRow - 1][currentPos.column] {
                selectedIndex = targetIndex
                return
            }
            // If exact column not available, find the rightmost cell in the row above
            for col in stride(from: currentPos.column, through: 0, by: -1) {
                if let targetIndex = gridLookup[currentPos.visualRow - 1][col] {
                    selectedIndex = targetIndex
                    return
                }
            }
        }
        // Already at top, don't move
    }

    func moveDown() {
        guard let current = selectedIndex,
              current < gridPositions.count,
              !displayedEmojis.isEmpty else {
            selectedIndex = 0
            return
        }

        let currentPos = gridPositions[current]
        let maxRow = gridLookup.count - 1

        // Try to find a cell directly below (same column, next row)
        if currentPos.visualRow < maxRow {
            // Look for a cell at (visualRow + 1, column)
            if let targetIndex = gridLookup[currentPos.visualRow + 1][currentPos.column] {
                selectedIndex = targetIndex
                return
            }
            // If exact column not available, find the rightmost cell in the row below
            for col in stride(from: currentPos.column, through: 0, by: -1) {
                if let targetIndex = gridLookup[currentPos.visualRow + 1][col] {
                    selectedIndex = targetIndex
                    return
                }
            }
        }
        // Already at bottom, don't move
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
        // Record usage for persistence, but don't update display
        // Visual update is deferred to next onShow() to avoid distracting reordering
        emojiStore.recordUsage(of: emoji)
        return emoji
    }

    func selectEmoji(_ emoji: Emoji) -> Emoji {
        if let index = displayedEmojis.firstIndex(of: emoji) { selectedIndex = index }
        // Record usage for persistence, but don't update display
        // Visual update is deferred to next onShow() to avoid distracting reordering
        emojiStore.recordUsage(of: emoji)
        return emoji
    }

    func onShow() {
        isVisible = true
        searchQuery = ""
        // Refresh recent emojis in case settings changed (e.g., frecencyRows)
        emojiStore.refreshRecentEmojis()
        updateDisplayedEmojis()
        // Trigger scroll to top
        scrollToTopTrigger += 1
    }

    func onHide() {
        isVisible = false
    }

    /// Records usage of an emoji without any selection or insertion logic.
    /// Used for copy-to-clipboard operations.
    /// Visual update is deferred to next onShow() to avoid distracting reordering.
    func recordUsage(of emoji: Emoji) {
        emojiStore.recordUsage(of: emoji)
    }
}
