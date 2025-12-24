//
//  HotkeyServiceProtocol.swift
//  BetterEmojiPicker
//
//  Protocol defining the interface for global hotkey registration.
//

import Foundation
import Carbon

/// Protocol for registering and handling global keyboard shortcuts.
protocol HotkeyServiceProtocol {
    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) -> Bool
    func unregisterAll()
}

/// Common virtual key codes.
enum KeyCode {
    static let space: UInt32 = UInt32(kVK_Space)
    static let escape: UInt32 = UInt32(kVK_Escape)
    static let returnKey: UInt32 = UInt32(kVK_Return)
}

/// Modifier key flags for hotkey registration.
enum ModifierFlags {
    static let command: UInt32 = UInt32(cmdKey)
    static let control: UInt32 = UInt32(controlKey)
    static let option: UInt32 = UInt32(optionKey)
    static let shift: UInt32 = UInt32(shiftKey)
    static let controlCommand: UInt32 = control | command
}
