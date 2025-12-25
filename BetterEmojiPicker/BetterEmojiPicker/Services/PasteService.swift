//
//  PasteService.swift
//  BetterEmojiPicker
//
//  Implements emoji insertion by copying to clipboard and simulating Cmd+V.
//

import AppKit
import Carbon

/// Production implementation of the paste service.
final class PasteService: PasteServiceProtocol {

    static let shared = PasteService()
    private init() {}

    private var savedPasteboardItems: [NSPasteboardItem] = []
    private var savedChangeCount: Int = 0

    func paste(text: String, targetPID: pid_t? = nil) -> Bool {
        guard hasPermission() else {
            print("⚠️ PasteService: Missing Accessibility permission")
            return false
        }

        saveClipboard()
        copyToClipboard(text: text)
        // Minimal delay - just enough for pasteboard to sync
        usleep(1_000) // 1ms
        simulatePaste(to: targetPID)

        // Use configurable delay from settings before restoring clipboard
        // Must access SettingsService on main thread
        DispatchQueue.main.async { [weak self] in
            let delayMs = SettingsService.shared.settings.clipboardRestoreDelay
            let delaySeconds = Double(delayMs) / 1000.0

            DispatchQueue.main.asyncAfter(deadline: .now() + delaySeconds) {
                self?.restoreClipboard()
            }
        }

        return true
    }

    func copyToClipboard(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    func hasPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func saveClipboard() {
        let pasteboard = NSPasteboard.general
        savedChangeCount = pasteboard.changeCount
        savedPasteboardItems = []

        guard let items = pasteboard.pasteboardItems else { return }

        for item in items {
            let newItem = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    newItem.setData(data, forType: type)
                }
            }
            savedPasteboardItems.append(newItem)
        }
    }

    private func restoreClipboard() {
        guard !savedPasteboardItems.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        let expectedChangeCount = savedChangeCount + 1
        if pasteboard.changeCount != expectedChangeCount {
            savedPasteboardItems = []
            return
        }

        pasteboard.clearContents()
        pasteboard.writeObjects(savedPasteboardItems)
        savedPasteboardItems = []
    }

    private func simulatePaste(to targetPID: pid_t? = nil) {
        let vKeyCode: CGKeyCode = 9
        let source = CGEventSource(stateID: .combinedSessionState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        if let pid = targetPID {
            // Post directly to the target process - most reliable
            keyDown.postToPid(pid)
            keyUp.postToPid(pid)
        } else {
            // Fallback to system-wide posting
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }
    }
}
