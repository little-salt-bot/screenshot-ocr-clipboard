#!/bin/bash
# Build ocrshot into a proper .app bundle so it appears in
# System Settings > Privacy & Security > Screen Recording.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$DIR/ocrshot.app"
BIN="$APP/Contents/MacOS/ocrshot"

echo "Compiling..."
swiftc -O "$DIR/ocrshot.swift" -o "$BIN"

echo "Writing Info.plist..."
mkdir -p "$APP/Contents"
cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>ocrshot</string>
    <key>CFBundleDisplayName</key>
    <string>ocrshot</string>
    <key>CFBundleIdentifier</key>
    <string>com.ocrshot.app</string>
    <key>CFBundleExecutable</key>
    <string>ocrshot</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "Done. Run it with:"
echo "  $APP/Contents/MacOS/ocrshot"
echo ""
echo "First run will prompt for Screen Recording access. If it doesn't,"
echo "open System Settings > Privacy & Security > Screen Recording,"
echo "click +, and add $APP"
