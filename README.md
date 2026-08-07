# Screenshot → OCR → Clipboard

One-shot macOS tool: take a screenshot, OCR all the text in it, and copy it straight to your clipboard. No dependencies, all native Apple frameworks.

## How it works

- **Screen Recording permission** — the app requests it on first run (System Settings → Privacy & Security → Screen Recording)
- **Interactive region selection** — drag to select an area, or click to cancel
- **Apple Vision framework** — accurate OCR with language correction
- **`NSPasteboard`** — text lands on your clipboard

## Usage

```bash
./ocrshot.sh
```

First run prompts for Screen Recording access. After granting it, run again, drag-select a region, and the text is on your clipboard.

## Files

- `ocrshot.sh` — runs the Swift app
- `ocrshot.swift` — the whole flow: permission → capture → OCR → clipboard

## Requirements

- macOS (uses the Vision framework, `CGWindowListCreateImage`, and `NSPasteboard`)
- Xcode Command Line Tools (for `swift`)

## Optional: global hotkey

Add a Quick Action in Shortcuts, or a keyboard shortcut under **System Settings → Keyboard → Shortcuts → Services**, that runs `ocrshot.sh` for a true one-key capture.
