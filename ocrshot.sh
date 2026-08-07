#!/bin/bash
# Screenshot -> OCR -> clipboard, all in one shot.
# The Swift app handles permission, capture, OCR, and clipboard.
# Usage: ./ocrshot.sh   (then drag-select a region)
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
swift "$DIR/ocrshot.swift"
