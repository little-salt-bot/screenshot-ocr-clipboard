import SwiftUI
import ServiceManagement

// Central settings store, persisted to UserDefaults.
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @AppStorage("hotkeyKeyCode") var hotkeyKeyCode: Int = 7 // 'X'
    @AppStorage("hotkeyModifiers") var hotkeyModifiers: Int = HotkeyModifier.command | HotkeyModifier.shift // ⌘⇧X
    @AppStorage("copyToClipboard") var copyToClipboard: Bool = true
    @AppStorage("grayscaleContrast") var grayscaleContrast: Bool = true
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false {
        didSet { applyLaunchAtLogin() }
    }
    @AppStorage("lastResult") var lastResult: String = ""

    private init() {
        // One-time migration: an earlier recorder allowed ESC (keycode 53) to
        // be set as the hotkey, which broke cancelling. Reset it to a safe
        // default if that happened. Guarded so it only runs once.
        let migrated = UserDefaults.standard.bool(forKey: "hotkeyEscapeMigrated")
        if !migrated {
            if hotkeyKeyCode == 53 { // ESC
                hotkeyKeyCode = 7
                hotkeyModifiers = HotkeyModifier.command | HotkeyModifier.shift // ⌘⇧X
            }
            UserDefaults.standard.set(true, forKey: "hotkeyEscapeMigrated")
        }
    }

    // MARK: - Launch at login

    func applyLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("Launch at login error: \(error)")
            }
        }
    }
}
