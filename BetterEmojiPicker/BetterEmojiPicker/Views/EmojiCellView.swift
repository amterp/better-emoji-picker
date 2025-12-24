//
//  EmojiCellView.swift
//  BetterEmojiPicker
//
//  A single emoji cell in the picker grid.
//

import SwiftUI

/// A single cell displaying an emoji in the picker grid.
struct EmojiCellView: View {

    let emoji: Emoji
    let isSelected: Bool
    let onSelect: (Emoji) -> Void

    @State private var isHovering = false

    private let cellSize: CGFloat = 36
    private let emojiFontSize: CGFloat = 24
    private let cornerRadius: CGFloat = 6

    var body: some View {
        Text(emoji.emoji)
            .font(.system(size: emojiFontSize))
            .frame(width: cellSize, height: cellSize)
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .onHover { hovering in isHovering = hovering }
            .onTapGesture { onSelect(emoji) }
            .accessibilityLabel(emoji.name)
    }

    @ViewBuilder
    private var backgroundView: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.accentColor.opacity(0.3))
        } else if isHovering {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.primary.opacity(0.1))
        } else {
            Color.clear
        }
    }
}
