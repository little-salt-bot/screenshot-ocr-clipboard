import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register the global hotkey from saved settings.
        let settings = SettingsStore.shared
        HotkeyManager.shared.register(
            keyCode: settings.hotkeyKeyCode,
            modifiers: settings.hotkeyModifiers
        )

        setupStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.unregister()
    }

    // MARK: - Status item

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "OcrShot")
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showMenu()
        } else {
            // Left click = capture immediately (one-shot feel)
            CaptureController.shared.capture()
        }
    }

    private func showMenu() {
        guard let button = statusItem?.button else { return }
        let menu = NSMenu()

        let captureItem = NSMenuItem(
            title: "Capture & Copy",
            action: #selector(captureAction),
            keyEquivalent: ""
        )
        captureItem.target = self
        menu.addItem(captureItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit OcrShot",
            action: #selector(quitAction),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    // MARK: - Actions

    @objc private func captureAction() {
        CaptureController.shared.capture()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingView(rootView: SettingsView())
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "OcrShot Settings"
            window.contentView = hosting
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitAction() {
        NSApplication.shared.terminate(nil)
    }
}
