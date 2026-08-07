import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @State private var recordingHotkey = false
    @State private var screenRecordingGranted = false

    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            HotkeyTab()
                .tabItem { Label("Shortcut", systemImage: "keyboard") }
            PermissionsTab()
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
        }
        .frame(width: 420, height: 320)
        .onAppear {
            screenRecordingGranted = CGPreflightScreenCaptureAccess()
        }
    }
}

// MARK: - General

struct GeneralTab: View {
    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        Form {
            Section("Capture") {
                Toggle("Copy text to clipboard", isOn: $settings.copyToClipboard)
                Toggle("Grayscale + contrast (dark mode)", isOn: $settings.grayscaleContrast)
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Hotkey

struct HotkeyTab: View {
    @ObservedObject private var settings = SettingsStore.shared
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Global shortcut to capture & copy")
                .font(.headline)

            HStack {
                Text("Shortcut")
                Spacer()
                Button {
                    startRecording()
                } label: {
                    Text(recording ? "Press keys…" : displayString)
                        .frame(minWidth: 120)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .disabled(recording)
            }

            Text("Click the button, then press the key combination you want to use.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !recording {
                Button("Reset to default (⌘⇧X)") {
                    settings.hotkeyKeyCode = 7
                    settings.hotkeyModifiers = HotkeyModifier.command | HotkeyModifier.shift
                    HotkeyManager.shared.register(
                        keyCode: settings.hotkeyKeyCode,
                        modifiers: settings.hotkeyModifiers
                    )
                }
            }
        }
        .padding()
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        recording = true
        // Local event monitor captures the next key press regardless of focus.
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard recording else { return event }

            // Ignore pure modifier presses (cmd/opt/ctrl/shift alone).
            let keyCode = Int(event.keyCode)
            if keyCode == 55 || keyCode == 56 || keyCode == 58 || keyCode == 59 || keyCode == 60 || keyCode == 61 || keyCode == 62 || keyCode == 63 || keyCode == 54 {
                return nil
            }

            settings.hotkeyKeyCode = keyCode
            settings.hotkeyModifiers = modifiers(from: event.modifierFlags)
            DebugLog.log("Recorded hotkey: keyCode=\(keyCode) modifiers=\(settings.hotkeyModifiers)")
            HotkeyManager.shared.register(
                keyCode: settings.hotkeyKeyCode,
                modifiers: settings.hotkeyModifiers
            )
            recording = false
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }

    // Read modifiers from the event itself, not global state (NSEvent.modifierFlags
    // can include stray flags like control that the user isn't actually pressing).
    private func modifiers(from flags: NSEvent.ModifierFlags) -> Int {
        var mods = 0
        if flags.contains(.command) { mods |= HotkeyModifier.command }
        if flags.contains(.option) { mods |= HotkeyModifier.option }
        if flags.contains(.control) { mods |= HotkeyModifier.control }
        if flags.contains(.shift) { mods |= HotkeyModifier.shift }
        return mods
    }

    private var displayString: String {
        var parts: [String] = []
        if settings.hotkeyModifiers & HotkeyModifier.command != 0 { parts.append("⌘") }
        if settings.hotkeyModifiers & HotkeyModifier.option != 0 { parts.append("⌥") }
        if settings.hotkeyModifiers & HotkeyModifier.control != 0 { parts.append("⌃") }
        if settings.hotkeyModifiers & HotkeyModifier.shift != 0 { parts.append("⇧") }
        parts.append(KeyCode.character(forKeyCode: settings.hotkeyKeyCode).uppercased())
        return parts.joined(separator: "")
    }
}

// MARK: - Permissions

struct PermissionsTab: View {
    @State private var screenRecordingGranted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Permissions")
                .font(.headline)

            HStack {
                Label("Screen Recording", systemImage: screenRecordingGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(screenRecordingGranted ? .green : .red)
                Spacer()
                if !screenRecordingGranted {
                    Button("Grant") {
                        CGRequestScreenCaptureAccess()
                    }
                }
            }

            Text("Screen Recording access is required to capture the screen. If it's not granted, the capture won't work.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        .padding()
        .onAppear {
            screenRecordingGranted = CGPreflightScreenCaptureAccess()
        }
    }
}
