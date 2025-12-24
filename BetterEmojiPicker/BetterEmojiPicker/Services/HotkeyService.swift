//
//  HotkeyService.swift
//  BetterEmojiPicker
//
//  Implements global hotkey registration using the Carbon Event API.
//

import Foundation
import Carbon

/// Production implementation of global hotkey registration using Carbon Events.
final class HotkeyService: HotkeyServiceProtocol {

    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var hotkeyHandler: (() -> Void)?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x42455021), id: 1)

    static let shared = HotkeyService()
    private init() {}

    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) -> Bool {
        unregisterAll()
        self.hotkeyHandler = handler

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        guard status == noErr else {
            print("⚠️ HotkeyService: Failed to install event handler, status: \(status)")
            return false
        }

        var hotKeyRefTemp: EventHotKeyRef?
        let hotKeyIDCopy = hotKeyID

        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyIDCopy,
            GetApplicationEventTarget(),
            0,
            &hotKeyRefTemp
        )

        guard registerStatus == noErr, let ref = hotKeyRefTemp else {
            print("⚠️ HotkeyService: Failed to register hot key, status: \(registerStatus)")
            if let handler = eventHandler {
                RemoveEventHandler(handler)
                eventHandler = nil
            }
            return false
        }

        hotKeyRef = ref
        print("✅ HotkeyService: Registered hotkey")
        return true
    }

    func unregisterAll() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        hotkeyHandler = nil
    }

    fileprivate func handleHotKeyPress() {
        DispatchQueue.main.async { [weak self] in
            self?.hotkeyHandler?()
        }
    }

    deinit { unregisterAll() }
}

private func hotKeyEventHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData = userData else { return OSStatus(eventNotHandledErr) }
    let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
    service.handleHotKeyPress()
    return noErr
}
