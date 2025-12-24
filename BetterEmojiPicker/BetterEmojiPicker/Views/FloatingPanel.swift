//
//  FloatingPanel.swift
//  BetterEmojiPicker
//
//  A custom NSPanel subclass that provides a floating, non-activating window.
//

import AppKit
import SwiftUI

/// A floating panel window that doesn't steal focus from other applications.
class FloatingPanel: NSPanel {

    init<Content: View>(
        contentRect: NSRect = NSRect(x: 0, y: 0, width: 400, height: 320),
        @ViewBuilder content: () -> Content
    ) {
        // Remove .titled to hide the title bar and window buttons entirely
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        configurePanel()
        self.contentView = NSHostingView(rootView: content())
    }

    private func configurePanel() {
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true
        self.hidesOnDeactivate = false

        // Allow panel to receive key events
        self.becomesKeyOnlyIfNeeded = false  // Changed: always become key when shown

        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        self.animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func positionNearMouse() {
        let mouseLocation = NSEvent.mouseLocation

        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main else {
            return
        }

        let screenFrame = screen.visibleFrame

        var panelOrigin = NSPoint(
            x: mouseLocation.x + 10,
            y: mouseLocation.y - self.frame.height - 10
        )

        if panelOrigin.x + self.frame.width > screenFrame.maxX {
            panelOrigin.x = screenFrame.maxX - self.frame.width - 10
        }
        if panelOrigin.x < screenFrame.minX {
            panelOrigin.x = screenFrame.minX + 10
        }
        if panelOrigin.y < screenFrame.minY {
            panelOrigin.y = mouseLocation.y + 10
        }
        if panelOrigin.y + self.frame.height > screenFrame.maxY {
            panelOrigin.y = screenFrame.maxY - self.frame.height - 10
        }

        self.setFrameOrigin(panelOrigin)
    }
}
