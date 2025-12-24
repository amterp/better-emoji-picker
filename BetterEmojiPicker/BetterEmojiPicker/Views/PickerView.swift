//
//  PickerView.swift
//  BetterEmojiPicker
//
//  The main emoji picker view combining search field and emoji grid.
//

import SwiftUI
import AppKit

/// The main emoji picker interface.
struct PickerView: View {

    @ObservedObject var viewModel: PickerViewModel

    let onInsertEmoji: (Emoji) -> Void
    let onDismiss: () -> Void


    private let panelWidth: CGFloat = 400
    private let panelHeight: CGFloat = 320
    private let cornerRadius: CGFloat = 12

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            EmojiGridView(
                emojis: viewModel.displayedEmojis,
                sectionTitle: viewModel.sectionTitle,
                selectedIndex: viewModel.selectedIndex,
                onSelect: handleEmojiClick
            )
        }
        .frame(width: panelWidth, height: panelHeight)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        // Use NSEvent-based keyboard handling for macOS 13 compatibility
        .background(
            KeyboardEventHandler(
                onUpArrow: { viewModel.moveUp() },
                onDownArrow: { viewModel.moveDown() },
                onLeftArrow: { viewModel.moveLeft() },
                onRightArrow: { viewModel.moveRight() },
                onReturn: { handleEnterKey() },
                onEscape: { onDismiss() }
            )
        )
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 14))

            FocusableTextField(
                text: $viewModel.searchQuery,
                placeholder: "Search emojis...",
                onSubmit: { handleEnterKey() }
            )
            .frame(height: 20)

            if !viewModel.searchQuery.isEmpty {
                Button(action: { viewModel.searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.05))
        )
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.regularMaterial)
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }

    private func handleEnterKey() {
        if let emoji = viewModel.confirmSelection() {
            onInsertEmoji(emoji)
        }
    }

    private func handleEmojiClick(_ emoji: Emoji) {
        let selectedEmoji = viewModel.selectEmoji(emoji)
        onInsertEmoji(selectedEmoji)
    }
}

// MARK: - Keyboard Event Handler

/// A SwiftUI view that monitors keyboard events using NSEvent.
/// This provides macOS 13.0 compatibility since onKeyPress requires macOS 14.0+.
struct KeyboardEventHandler: NSViewRepresentable {

    let onUpArrow: () -> Void
    let onDownArrow: () -> Void
    let onLeftArrow: () -> Void
    let onRightArrow: () -> Void
    let onReturn: () -> Void
    let onEscape: () -> Void

    func makeNSView(context: Context) -> KeyboardHandlerView {
        let view = KeyboardHandlerView()
        view.onUpArrow = onUpArrow
        view.onDownArrow = onDownArrow
        view.onLeftArrow = onLeftArrow
        view.onRightArrow = onRightArrow
        view.onReturn = onReturn
        view.onEscape = onEscape
        return view
    }

    func updateNSView(_ nsView: KeyboardHandlerView, context: Context) {
        nsView.onUpArrow = onUpArrow
        nsView.onDownArrow = onDownArrow
        nsView.onLeftArrow = onLeftArrow
        nsView.onRightArrow = onRightArrow
        nsView.onReturn = onReturn
        nsView.onEscape = onEscape
    }
}

/// Custom NSView that captures keyboard events.
class KeyboardHandlerView: NSView {

    var onUpArrow: (() -> Void)?
    var onDownArrow: (() -> Void)?
    var onLeftArrow: (() -> Void)?
    var onRightArrow: (() -> Void)?
    var onReturn: (() -> Void)?
    var onEscape: (() -> Void)?

    private var localMonitor: Any?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupMonitor()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupMonitor()
    }

    private func setupMonitor() {
        // Monitor keyboard events locally (when our window has focus)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            // Check for special keys
            switch event.keyCode {
            case 126: // Up arrow
                self.onUpArrow?()
                return nil // Consume the event

            case 125: // Down arrow
                self.onDownArrow?()
                return nil

            case 123: // Left arrow
                self.onLeftArrow?()
                return nil

            case 124: // Right arrow
                self.onRightArrow?()
                return nil

            case 36: // Return
                self.onReturn?()
                return nil

            case 53: // Escape
                self.onEscape?()
                return nil

            default:
                return event // Let other keys pass through
            }
        }
    }

    deinit {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
