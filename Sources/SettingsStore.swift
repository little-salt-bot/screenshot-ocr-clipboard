import SwiftUI
import ServiceManagement

// Central settings store, persisted to UserDefaults.
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @AppStorage("hotkeyKeyCode") var hotkeyKeyCode: Int = 7 // 'X'
    @AppStorage("hotkeyModifiers") var hotkeyModifiers: Int = 0x1000 // cmd
    @AppStorage("copyToClipboard") var copyToClipboard: Bool = true
    @AppStorage("grayscaleContrast") var grayscaleContrast: Bool = true
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false {
        didSet { applyLaunchAtLogin() }
    }
    @AppStorage("lastResult") var lastResult: String = ""

    private init() {}

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
