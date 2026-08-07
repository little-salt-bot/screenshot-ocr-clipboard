# Screenshot → OCR → Clipboard

One-shot macOS tool: take a screenshot, OCR all the text in it, and copy it straight to your clipboard. No dependencies, all native Apple frameworks.

## How it works

- `screencapture -i` — interactive region/window selection
- Apple **Vision framework** — accurate OCR with language correction
- `pbcopy` — text lands on your clipboard

## Usage

```bash
./ocrshot.sh
```

Drag-select a region (or click a window). The text is on your clipboard.

## Files

- `ocrshot.sh` — the one-shot entry point (screenshot → OCR → clipboard)
- `ocr.swift` — Vision framework OCR, prints recognized text lines

## Requirements

- macOS (uses `screencapture`, `pbcopy`, and the Vision framework)
- Xcode Command Line Tools (for `swift`)

## Optional: global hotkey

Add a Quick Action in Shortcuts, or a keyboard shortcut under **System Settings → Keyboard → Shortcuts → Services**, that runs `ocrshot.sh` for a true one-key capture.
