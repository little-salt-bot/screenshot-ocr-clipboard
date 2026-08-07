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
        // One-time migration: older versions defaulted to ⌘X (command only),
        // which conflicts with the system Cut shortcut and never registers.
        // Bump it to ⌘⇧X if it's still the old broken default.
        if hotkeyKeyCode == 7 && hotkeyModifiers == HotkeyModifier.command {
            hotkeyKeyCode = 7
            hotkeyModifiers = HotkeyModifier.command | HotkeyModifier.shift
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
