#!/bin/bash
# Screenshot -> OCR -> clipboard, all in one shot.
# Usage: ./ocrshot.sh   (then drag-select a region, or click a window)
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
SHOT="/tmp/ocr_shot_$(date +%s).png"

# Interactive screenshot: drag to select a region, or click a window.
screencapture -i "$SHOT"

if [ ! -f "$SHOT" ]; then
    echo "Screenshot cancelled." >&2
    exit 1
fi

swift "$DIR/ocr.swift" "$SHOT" | pbcopy
rm -f "$SHOT"
echo "Text copied to clipboard."
