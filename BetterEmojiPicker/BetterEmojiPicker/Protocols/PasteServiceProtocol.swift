//
//  PasteServiceProtocol.swift
//  BetterEmojiPicker
//
//  Protocol defining the interface for pasting text into other applications.
//

import Foundation

/// Protocol for pasting content into the currently focused application.
protocol PasteServiceProtocol {
    func paste(text: String) -> Bool
    func copyToClipboard(text: String)
    func hasPermission() -> Bool
    func requestPermission()
}
