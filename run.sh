#!/bin/bash
# Launch OcrShot via LaunchServices so macOS registers it for
# Screen Recording permission.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$DIR/OcrShot.app"

if [ ! -d "$APP" ]; then
    echo "App not built yet. Run ./build.sh first."
    exit 1
fi

open "$APP"
