import AppKit
import ApplicationServices

// Global hotkey via event monitors.
//  - Global monitor: fires when the app is in the BACKGROUND. Requires
//    Accessibility permission.
//  - Local monitor: fires when the app is in the FOREGROUND. No permission.
//
// Critical gotcha: a global monitor created BEFORE Accessibility is granted
// stays untrusted even after the grant. So we observe the AX-trust-change
// notification and re-register the global monitor the moment it's granted.
final class HotkeyManager {
    static let shared = HotkeyManager()

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var axObserver: NSObjectProtocol?
    private var currentKeyCode: Int = 0
    private var currentModifiers: Int = 0

    private init() {
        // When Accessibility is granted/revoked, macOS posts this notification.
        // Re-register the global monitor so it picks up the new trust state.
        axObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.accessibility.api"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DebugLog.log("AX trust changed, re-registering global monitor")
            self?.reRegisterGlobalMonitor()
        }
    }

    // Register the hotkey. Returns false if no monitor could be created.
    @discardableResult
    func register(keyCode: Int, modifiers: Int) -> Bool {
        unregister()
        currentKeyCode = keyCode
        currentModifiers = modifiers
        DebugLog.log("register() called: keyCode=\(keyCode) modifiers=\(modifiers) axTrusted=\(AXIsProcessTrusted())")

        registerLocalMonitor()
        registerGlobalMonitorIfTrusted()

        return globalMonitor != nil || localMonitor != nil
    }

    private func registerGlobalMonitorIfTrusted() {
        if !AXIsProcessTrusted() {
            DebugLog.log("AX not trusted — global (background) hotkey disabled. Grant Accessibility and it will auto-enable.")
            return
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            if Int(event.keyCode) == self.currentKeyCode && self.matches(event.modifierFlags) {
                DebugLog.log("GLOBAL MONITOR: hotkey matched")
                CaptureController.shared.capture()
            }
        }
        DebugLog.log("Global monitor created: \(globalMonitor != nil)")
    }

    private func reRegisterGlobalMonitor() {
        if let m = globalMonitor {
            NSEvent.removeMonitor(m)
            globalMonitor = nil
        }
        registerGlobalMonitorIfTrusted()
    }

    private func registerLocalMonitor() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            if Int(event.keyCode) == self.currentKeyCode && self.matches(event.modifierFlags) {
                DebugLog.log("LOCAL MONITOR: hotkey matched")
                CaptureController.shared.capture()
                return nil
            }
            return event
        }
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
