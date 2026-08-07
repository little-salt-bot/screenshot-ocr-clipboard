import AppKit

// Global hotkey via a global event monitor. More reliable than Carbon
// for this use case, and simpler to reason about.
final class HotkeyManager {
    static let shared = HotkeyManager()

    private var monitor: Any?
    private var keyCode: Int = 0
    private var modifiers: Int = 0

    private init() {}

    // Register the global hotkey. Returns false if the monitor couldn't be created.
    @discardableResult
    func register(keyCode: Int, modifiers: Int) -> Bool {
        unregister()
        self.keyCode = keyCode
        self.modifiers = modifiers

        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            if Int(event.keyCode) == self.keyCode && self.matchesModifiers(event.modifierFlags) {
                CaptureController.shared.capture()
            }
        }
        return monitor != nil
    }

    func unregister() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }

    private func matchesModifiers(_ flags: NSEvent.ModifierFlags) -> Bool {
        let cmd = flags.contains(.command)
        let opt = flags.contains(.option)
        let ctl = flags.contains(.control)
        let shf = flags.contains(.shift)
        return cmd == (modifiers & HotkeyModifier.command != 0)
            && opt == (modifiers & HotkeyModifier.option != 0)
            && ctl == (modifiers & HotkeyModifier.control != 0)
            && shf == (modifiers & HotkeyModifier.shift != 0)
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
