#!/bin/bash
# Build OcrShot into a proper .app bundle.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$DIR/OcrShot.app"
BIN="$APP/Contents/MacOS/OcrShot"

echo "Compiling..."
mkdir -p "$APP/Contents/MacOS"
swiftc -O \
    "$DIR/Sources/OcrShotApp.swift" \
    "$DIR/Sources/AppDelegate.swift" \
    "$DIR/Sources/DebugLog.swift" \
    "$DIR/Sources/HotkeyManager.swift" \
    "$DIR/Sources/CaptureController.swift" \
    "$DIR/Sources/SettingsStore.swift" \
    "$DIR/Sources/SettingsView.swift" \
    -o "$BIN"

echo "Writing Info.plist..."
mkdir -p "$APP/Contents"
cp "$DIR/Info.plist" "$APP/Contents/Info.plist"

echo "Done. Run with: ./run.sh"
