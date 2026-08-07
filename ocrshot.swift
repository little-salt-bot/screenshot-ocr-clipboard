import AppKit
import Vision
import CoreGraphics

// ============================================================
// 1. Screen Recording permission
// ============================================================
if !CGPreflightScreenCaptureAccess() {
    print("Requesting Screen Recording permission...")
    CGRequestScreenCaptureAccess()
    print("Grant Screen Recording access in System Settings > Privacy & Security > Screen Recording, then run this again.")
    exit(0)
}

// ============================================================
// 2. Interactive region selection overlay
// ============================================================
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

final class SelectionWindow: NSWindow {
    var startPoint: NSPoint = .zero
    var selectionRect: NSRect = .zero
    var onComplete: ((NSRect) -> Void)?

    override var canBecomeKey: Bool { true }

    override func mouseDown(with event: NSEvent) {
        startPoint = event.locationInWindow
        selectionRect = .zero
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let p = event.locationInWindow
        selectionRect = NSRect(
            x: min(startPoint.x, p.x),
            y: min(startPoint.y, p.y),
            width: abs(p.x - startPoint.x),
            height: abs(p.y - startPoint.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if selectionRect.width > 5 && selectionRect.height > 5 {
            onComplete?(selectionRect)
        } else {
            NSApp.terminate(nil) // cancelled
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.3).setFill()
        dirtyRect.fill()
        if selectionRect.width > 0 {
            NSColor.clear.setFill()
            selectionRect.fill(using: .copy)
            NSColor.systemBlue.setStroke()
            let path = NSBezierPath(rect: selectionRect)
            path.lineWidth = 2
            path.stroke()
        }
    }
}

guard let screen = NSScreen.main else {
    fputs("No main screen found.\n", stderr)
    exit(1)
}

let window = SelectionWindow(
    contentRect: screen.frame,
    styleMask: [.borderless],
    backing: .buffered,
    defer: false
)
window.level = .screenSaver
window.isOpaque = false
window.backgroundColor = .clear
window.ignoresMouseEvents = false
window.makeKeyAndOrderFront(nil)

// ============================================================
// 3. Capture, OCR, clipboard
// ============================================================
window.onComplete = { rect in
    // Convert window (bottom-left origin) to CG capture (top-left origin)
    let captureRect = NSRect(
        x: rect.minX,
        y: screen.frame.height - rect.maxY,
        width: rect.width,
        height: rect.height
    )

    guard let cg = CGWindowListCreateImage(
        captureRect, .optionOnScreenOnly, kCGNullWindowID, .bestResolution
    ) else {
        fputs("Capture failed.\n", stderr)
        NSApp.terminate(nil)
        return
    }

    let request = VNRecognizeTextRequest { req, _ in
        guard let obs = req.results as? [VNRecognizedTextObservation] else { return }
        let text = obs.compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")

        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        print("Copied \(text.count) characters to clipboard.")
        NSApp.terminate(nil)
    }
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true

    let handler = VNImageRequestHandler(cgImage: cg, options: [:])
    try? handler.perform([request])
}

app.run()
