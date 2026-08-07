#!/bin/bash
# Launch ocrshot via LaunchServices (open) so macOS registers it
# for Screen Recording permission. Running the binary directly from
# the terminal does NOT register it with TCC.
#
# Usage:
#   ./run.sh            # normal
#   ./run.sh --debug    # verbose logging to ~/ocrshot.log + saves debug images
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$DIR/ocrshot.app"

if [ ! -d "$APP" ]; then
    echo "App not built yet. Run ./build.sh first."
    exit 1
fi

if [ "$1" == "--debug" ]; then
    # Launch via open so the bundle keeps its Screen Recording permission.
    # Console output isn't visible, but everything logs to ~/ocrshot.log
    # and debug images are saved to the home dir.
    open "$APP" --args --debug
else
    open "$APP"
fi
