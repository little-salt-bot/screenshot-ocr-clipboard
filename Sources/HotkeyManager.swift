import Carbon
import AppKit

// Global hotkey registration via the Carbon Event Manager.
// Carbon is the only way to register a truly global hotkey without
// accessibility permissions or a third-party library.
final class HotkeyManager {
    static let shared = HotkeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyID = EventHotKeyID(signature: 0x4F4352, id: 1) // 'OCRS'

    private init() {}

    // Register the global hotkey. Returns false if registration failed
    // (e.g. the shortcut is already taken by another app).
    @discardableResult
    func register(keyCode: Int, modifiers: Int) -> Bool {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // Install the event handler once.
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, _ -> OSStatus in
                var hkID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                if hkID.signature == 0x4F4352 {
                    CaptureController.shared.capture()
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )

        hotKeyID.id = 1
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(modifiers),
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        return status == noErr
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }
}

// MARK: - Key code helpers

enum KeyCode {
    static func fromCharacter(_ c: Character) -> Int? {
        let lower = String(c).lowercased()
        guard let scalar = lower.unicodeScalars.first else { return nil }
        let v = Int(scalar.value)
        if v >= 97 && v <= 122 { return v - 97 + 0 } // a-z -> 0-25
        if v >= 48 && v <= 57 { return v - 48 + 18 } // 0-9 -> 18-27
        return nil
    }

    static func character(forKeyCode code: Int) -> String {
        if code >= 0 && code <= 25 { return String(UnicodeScalar(97 + code)!) }
        if code >= 18 && code <= 27 { return String(UnicodeScalar(48 + code - 18)!) }
        return "?"
    }
}

// Carbon modifier flags
enum HotkeyModifier {
    static let command = 0x1000
    static let option = 0x0800
    static let control = 0x2000
    static let shift = 0x0200
}
