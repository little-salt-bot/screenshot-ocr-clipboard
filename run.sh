#!/bin/bash
# Launch ocrshot via LaunchServices (open) so macOS registers it
# for Screen Recording permission. Running the binary directly from
# the terminal does NOT register it with TCC.
#
# Usage:
#   ./run.sh            # normal
#   ./run.sh --debug    # verbose console logging + saves debug images
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$DIR/ocrshot.app"
BIN="$APP/Contents/MacOS/ocrshot"

if [ ! -d "$APP" ]; then
    echo "App not built yet. Run ./build.sh first."
    exit 1
fi

if [ "$1" == "--debug" ]; then
    # Run the binary directly so console output is visible.
    "$BIN" --debug
else
    open "$APP"
fi
