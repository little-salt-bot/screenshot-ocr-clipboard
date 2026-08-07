# OcrShot

A macOS menu bar app that captures a screen region, OCRs all the text in it, and copies it to your clipboard — all in one shot. No dependencies, all native Apple frameworks.

## Features

- **Menu bar app** — lives in the status bar, no dock icon
- **Global hotkey** — capture & copy from anywhere (default `⌘⇧X`, configurable)
- **Drag-to-select** — crosshair reticle, works across all monitors
- **Dark mode OCR** — optional grayscale + contrast preprocessing for light-on-dark text
- **Launch at login** — optional
- **Permissions UI** — check and grant Screen Recording access from the app

## Build & Run

```bash
./build.sh   # compile into OcrShot.app
./run.sh     # launch via LaunchServices (registers for Screen Recording)
```

First run prompts for Screen Recording access. Grant it in System Settings → Privacy & Security → Screen Recording, then use the hotkey or the menu bar item.

## Usage

- **Hotkey** (default `⌘⇧X`) — start a capture
- **Menu bar icon** — click to capture, or open Settings
- **Drag** to select a region, **ESC** to cancel
- Text is copied to the clipboard automatically

## Settings

- **Shortcut** — record a custom global hotkey
- **General** — toggle clipboard copy, dark-mode preprocessing, launch at login
- **Permissions** — view/grant Screen Recording access

## Architecture

- `Sources/OcrShotApp.swift` — SwiftUI `MenuBarExtra` + `Settings` scene
- `Sources/AppDelegate.swift` — hotkey registration on launch
- `Sources/HotkeyManager.swift` — Carbon global hotkey + keycode helpers
- `Sources/CaptureController.swift` — overlay, ScreenCaptureKit capture, Vision OCR
- `Sources/SettingsStore.swift` — `@AppStorage`-backed settings
- `Sources/SettingsView.swift` — SwiftUI settings UI

## Requirements

- macOS 13+ (uses `MenuBarExtra`, `ScreenCaptureKit`, Vision)
- Xcode Command Line Tools (for `swiftc`)
