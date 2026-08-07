import AppKit
import Vision
import ScreenCaptureKit

// ============================================================
// 1. Screen Recording permission
// ============================================================
if !CGPreflightScreenCaptureAccess() {
    print("Requesting Screen Recording permission...")
    CGRequestScreenCaptureAccess()
    print("Grant Screen Recording access in System Settings > Privacy & Security > Screen Recording, then run this again.")
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.activate(ignoringOtherApps: true)

// ============================================================
// 2. Overlay view: dims screen, drag to select a region
// ============================================================
final class OverlayView: NSView {
    var startPoint: NSPoint = .zero
    var selectionRect: NSRect = .zero
    var onComplete: ((NSRect) -> Void)?

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        selectionRect = .zero
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
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
        bounds.fill()
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

// One overlay window per screen, so selection works on any monitor.
var windows: [NSWindow] = []
var overlays: [OverlayView] = []

for screen in NSScreen.screens {
    let window = NSWindow(
        contentRect: screen.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.level = .screenSaver
    window.isOpaque = false
    window.backgroundColor = .clear
    window.ignoresMouseEvents = false

    let overlay = OverlayView(frame: screen.frame)
    window.contentView = overlay
    window.makeKeyAndOrderFront(nil)
    window.orderFrontRegardless()

    windows.append(window)
    overlays.append(overlay)
}

// Safety: auto-exit if no selection within 60s (prevents silent hang)
DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
    if overlays.allSatisfy({ $0.selectionRect.width == 0 }) {
        print("Timed out waiting for selection.")
        NSApp.terminate(nil)
    }
}

// ============================================================
// 3. Capture (ScreenCaptureKit), OCR, clipboard
// ============================================================
for (i, overlay) in overlays.enumerated() {
    let screen = NSScreen.screens[i]
    overlay.onComplete = { rect in
        Task { @MainActor in
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first(where: { $0.frame == screen.frame })
                    ?? content.displays.first else {
                    fputs("No display found for selection.\n", stderr)
                    NSApp.terminate(nil)
                    return
                }

                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = SCStreamConfiguration()
                config.width = Int(display.frame.width)
                config.height = Int(display.frame.height)
                config.showsCursor = false

                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

                // Convert selection (points, bottom-left, global) to pixel crop on this display
                let scale = CGFloat(image.width) / display.frame.width
                let cropRect = CGRect(
                    x: (rect.minX - display.frame.minX) * scale,
                    y: (rect.minY - display.frame.minY) * scale,
                    width: rect.width * scale,
                    height: rect.height * scale
                )
                guard let cropped = image.cropping(to: cropRect) else {
                    fputs("Crop failed.\n", stderr)
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

                let handler = VNImageRequestHandler(cgImage: cropped, options: [:])
                try handler.perform([request])
            } catch {
                fputs("Capture failed: \(error)\n", stderr)
                NSApp.terminate(nil)
            }
        }
    }
}

app.run()
