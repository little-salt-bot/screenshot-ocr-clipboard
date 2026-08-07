#!/bin/bash
# Launch ocrshot via LaunchServices (open) so macOS registers it
# for Screen Recording permission. Running the binary directly from
# the terminal does NOT register it with TCC.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$DIR/ocrshot.app"

if [ ! -d "$APP" ]; then
    echo "App not built yet. Run ./build.sh first."
    exit 1
fi

open "$APP"
