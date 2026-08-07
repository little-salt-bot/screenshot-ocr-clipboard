import Carbon
import AppKit

// Global hotkey via Carbon RegisterEventHotKey. This is the only way to
// get a truly global hotkey WITHOUT Accessibility permission. Global event
// monitors (NSEvent.addGlobalMonitorForEvents) require AX trust, which is
// why the previous approach never fired.
final class HotkeyManager {
    static let shared = HotkeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var handlerInstalled = false
    private var localMonitor: Any?
    private let hotKeySignature: OSType = 0x4F4352 // 'OCRS'
    private var currentKeyCode: Int = 0
    private var currentModifiers: Int = 0

    private init() {}

    // Register the global hotkey. Returns false if registration failed
    // (e.g. the shortcut is already taken by another app).
    @discardableResult
    func register(keyCode: Int, modifiers: Int) -> Bool {
        unregister()
        currentKeyCode = keyCode
        currentModifiers = modifiers
        DebugLog.log("register() called: keyCode=\(keyCode) modifiers=\(modifiers)")

        // Carbon hotkey fires when the app is NOT active (background).
        if !handlerInstalled {
            installHandler()
        }
        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: 1)
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(modifiers),
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        DebugLog.log("RegisterEventHotKey status=\(status) (0=success) hotKeyRef=\(String(describing: hotKeyRef))")

        // Local event monitor fires when the app IS active (foreground).
        // Carbon hotkeys don't fire while the app is frontmost, so this
        // covers the case where the user tests right after launching.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            if Int(event.keyCode) == self.currentKeyCode && self.matchesModifiers(event.modifierFlags) {
                DebugLog.log("LOCAL MONITOR: hotkey matched")
                CaptureController.shared.capture()
                return nil
            }
            return event
        }

        return status == noErr
    }

    private func matchesModifiers(_ flags: NSEvent.ModifierFlags) -> Bool {
        let cmd = flags.contains(.command)
        let opt = flags.contains(.option)
        let ctl = flags.contains(.control)
        let shf = flags.contains(.shift)
        return cmd == (currentModifiers & HotkeyModifier.command != 0)
            && opt == (currentModifiers & HotkeyModifier.option != 0)
            && ctl == (currentModifiers & HotkeyModifier.control != 0)
            && shf == (currentModifiers & HotkeyModifier.shift != 0)
    }

    private func installHandler() {
        DebugLog.log("installHandler() called")
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let installStatus = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, _ -> OSStatus in
                DebugLog.log("HOTKEY CALLBACK FIRED")
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
                    DebugLog.log("Signature match, triggering capture")
                    CaptureController.shared.capture()
                } else {
                    DebugLog.log("Signature mismatch: \(hkID.signature)")
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )
        DebugLog.log("InstallEventHandler status=\(installStatus)")
        handlerInstalled = true
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let m = localMonitor {
            NSEvent.removeMonitor(m)
            localMonitor = nil
        }
    }
}

// MARK: - Key code helpers

// macOS virtual keycodes for common keys.
enum KeyCode {
    static let kVK_ANSI_X: UInt16 = 7

    // Map a keycode to a display character for common keys.
    static func character(forKeyCode code: Int) -> String {
        let map: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "5",
            23: "6", 24: "7", 25: "8", 26: "9", 27: "0", 28: "-", 29: "=",
            30: "[", 31: "]", 33: ";", 35: "/", 36: "Return", 48: "Tab",
            49: "Space", 51: "Delete", 53: "Esc", 123: "←", 124: "→",
            125: "↓", 126: "↑"
        ]
        return map[code] ?? "?"
    }
}

// Carbon modifier flags (kept for settings storage compatibility)
enum HotkeyModifier {
    static let command = 0x1000
    static let option = 0x0800
    static let control = 0x2000
    static let shift = 0x0200
}
