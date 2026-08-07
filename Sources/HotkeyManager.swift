import AppKit
import ApplicationServices

// Global hotkey via event monitors. Two monitors cover all cases:
//  - Global monitor: fires when the app is NOT active (background).
//  - Local monitor: fires when the app IS active (foreground).
// Global key monitors require Accessibility permission, which we request.
final class HotkeyManager {
    static let shared = HotkeyManager()

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var currentKeyCode: Int = 0
    private var currentModifiers: Int = 0

    private init() {}

    // Register the global hotkey. Returns false if neither monitor could be created.
    @discardableResult
    func register(keyCode: Int, modifiers: Int) -> Bool {
        unregister()
        currentKeyCode = keyCode
        currentModifiers = modifiers
        DebugLog.log("register() called: keyCode=\(keyCode) modifiers=\(modifiers)")

        // Global monitor: fires when the app is in the background.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            if Int(event.keyCode) == self.currentKeyCode && self.matches(event.modifierFlags) {
                DebugLog.log("GLOBAL MONITOR: hotkey matched")
                CaptureController.shared.capture()
            }
        }

        // Local monitor: fires when the app is in the foreground.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            if Int(event.keyCode) == self.currentKeyCode && self.matches(event.modifierFlags) {
                DebugLog.log("LOCAL MONITOR: hotkey matched")
                CaptureController.shared.capture()
                return nil
            }
            return event
        }

        DebugLog.log("globalMonitor=\(globalMonitor != nil) localMonitor=\(localMonitor != nil)")
        return globalMonitor != nil || localMonitor != nil
    }

    private func matches(_ flags: NSEvent.ModifierFlags) -> Bool {
        let cmd = flags.contains(.command)
        let opt = flags.contains(.option)
        let ctl = flags.contains(.control)
        let shf = flags.contains(.shift)
        return cmd == (currentModifiers & HotkeyModifier.command != 0)
            && opt == (currentModifiers & HotkeyModifier.option != 0)
            && ctl == (currentModifiers & HotkeyModifier.control != 0)
            && shf == (currentModifiers & HotkeyModifier.shift != 0)
    }

    func unregister() {
        if let m = globalMonitor {
            NSEvent.removeMonitor(m)
            globalMonitor = nil
        }
        if let m = localMonitor {
            NSEvent.removeMonitor(m)
            localMonitor = nil
        }
    }

    // Request Accessibility permission (needed for the global key monitor).
    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
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
