import SwiftUI
import AppKit

@main
struct OcrShotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
        } label: {
            Image(systemName: "text.viewfinder")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}

// The menu bar dropdown content.
struct MenuBarView: View {
    @Environment(\.openSettings) private var openSettings
    @State private var lastResult: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                CaptureController.shared.capture()
            } label: {
                Label("Capture & Copy", systemImage: "text.viewfinder")
            }

            Divider()

            if let last = lastResult {
                Text(last)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Divider()

            Button {
                openSettings()
            } label: {
                Label("Settings…", systemImage: "gearshape")
            }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
        }
        .padding(8)
        .frame(width: 240)
        .onAppear {
            lastResult = CaptureController.shared.lastResult
        }
    }
}
