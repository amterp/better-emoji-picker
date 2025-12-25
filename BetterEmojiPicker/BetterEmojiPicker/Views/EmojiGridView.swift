//
//  EmojiGridView.swift
//  BetterEmojiPicker
//
//  A scrollable grid of emoji cells organized by sections.
//

import SwiftUI

/// A scrollable grid displaying emojis in sections with a fixed-column layout.
struct EmojiGridView: View {

    let sections: [EmojiSection]
    let displayedEmojis: [Emoji]  // Flat list for selection index mapping
    let selectedIndex: Int?
    let scrollToTopTrigger: Int  // Increment to trigger scroll-to-top
    let onSelect: (Emoji) -> Void

    private let columnCount = 10
    private let topAnchorId = "grid-top-anchor"

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 2), count: columnCount)
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    // Invisible anchor at the very top for scroll-to-top
                    Color.clear
                        .frame(height: 0)
                        .id(topAnchorId)

                    if sections.isEmpty || (sections.count == 1 && sections[0].emojis.isEmpty) {
                        emptyState
                    } else {
                        ForEach(sections) { section in
                            sectionView(section)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            // Scroll to top when trigger changes
            .onChange(of: scrollToTopTrigger) { _ in
                scrollProxy.scrollTo(topAnchorId, anchor: .top)
            }
            // Scroll to selection when it changes
            .onChange(of: selectedIndex) { newValue in
                if let index = newValue, index < displayedEmojis.count {
                    // Find which section and position this index corresponds to
                    if let scrollId = scrollIdForIndex(index) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            scrollProxy.scrollTo(scrollId, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    /// Computes the starting index in displayedEmojis for each section.
    /// This allows us to correctly highlight emojis even when they appear in multiple sections.
    private var sectionStartIndices: [String: Int] {
        var indices: [String: Int] = [:]
        var currentIndex = 0
        for section in sections {
            indices[section.id] = currentIndex
            currentIndex += section.emojis.count
        }
        return indices
    }

    /// Converts a flat index to the scroll ID used in the grid.
    private func scrollIdForIndex(_ index: Int) -> String? {
        var remaining = index
        for section in sections {
            if remaining < section.emojis.count {
                return "\(section.id)-\(remaining)"
            }
            remaining -= section.emojis.count
        }
        return nil
    }

    @ViewBuilder
    private func sectionView(_ section: EmojiSection) -> some View {
        let sectionStart = sectionStartIndices[section.id] ?? 0

        VStack(alignment: .leading, spacing: 6) {
            // Section header
            Text(section.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.leading, 4)

            // Emoji grid for this section
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(section.emojis.enumerated()), id: \.offset) { index, emoji in
                    let absoluteIndex = sectionStart + index
                    EmojiCellView(
                        emoji: emoji,
                        isSelected: absoluteIndex == selectedIndex,
                        onSelect: onSelect
                    )
                    .id("\(section.id)-\(index)")  // Unique ID per section position
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No emojis found")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Try a different search term")
                .font(.caption)
                .foregroundColor(.gray)  // Use .gray instead of .tertiary for macOS 13
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
