//
//  EmojiGridView.swift
//  BetterEmojiPicker
//
//  A scrollable grid of emoji cells.
//

import SwiftUI

/// A scrollable grid displaying emojis in a fixed-column layout.
struct EmojiGridView: View {

    let emojis: [Emoji]
    let sectionTitle: String
    let selectedIndex: Int?
    let onSelect: (Emoji) -> Void

    private let columnCount = 10

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 2), count: columnCount)
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader

                    if emojis.isEmpty {
                        emptyState
                    } else {
                        emojiGrid
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            // macOS 13.0 compatible onChange syntax
            .onChange(of: selectedIndex) { newValue in
                if let index = newValue, index < emojis.count {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        scrollProxy.scrollTo(emojis[index].id, anchor: .center)
                    }
                }
            }
        }
    }

    private var sectionHeader: some View {
        Text(sectionTitle)
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.leading, 4)
            .padding(.top, 4)
    }

    private var emojiGrid: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Array(emojis.enumerated()), id: \.element.id) { index, emoji in
                EmojiCellView(
                    emoji: emoji,
                    isSelected: index == selectedIndex,
                    onSelect: onSelect
                )
                .id(emoji.id)
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
