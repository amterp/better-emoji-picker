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
    let onSelect: (Emoji) -> Void

    private let columnCount = 10

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 2), count: columnCount)
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
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
            // macOS 13.0 compatible onChange syntax
            .onChange(of: selectedIndex) { newValue in
                if let index = newValue, index < displayedEmojis.count {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        scrollProxy.scrollTo(displayedEmojis[index].id, anchor: .center)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sectionView(_ section: EmojiSection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Section header
            Text(section.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.leading, 4)

            // Emoji grid for this section
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(section.emojis) { emoji in
                    let flatIndex = displayedEmojis.firstIndex(of: emoji)
                    EmojiCellView(
                        emoji: emoji,
                        isSelected: flatIndex == selectedIndex,
                        onSelect: onSelect
                    )
                    .id(emoji.id)
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
