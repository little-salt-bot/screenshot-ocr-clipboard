import AppKit
import Vision
import ScreenCaptureKit

// Log to a file so errors are visible even when launched via `open`.
let logPath = NSString(string: "~/ocrshot.log").expandingTildeInPath
func log(_ msg: String) {
    let line = "[\(Date())] \(msg)\n"
    if let h = FileHandle(forWritingAtPath: logPath) {
        h.seekToEndOfFile()
        h.write(line.data(using: .utf8)!)
        h.closeFile()
    } else {
        try? line.data(using: .utf8)?.write(to: URL(fileURLWithPath: logPath))
    }
}
log("=== ocrshot started ===")

// ============================================================
// 1. Screen Recording permission
// ============================================================
if !CGPreflightScreenCaptureAccess() {
    log("No screen recording permission yet.")
    print("Requesting Screen Recording permission...")
    CGRequestScreenCaptureAccess()
    print("Grant Screen Recording access in System Settings > Privacy & Security > Screen Recording, then run this again.")
    exit(0)
}
log("Screen recording permission OK.")

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

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for ta in trackingAreas { removeTrackingArea(ta) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .inVisibleRect, .cursorUpdate],
            owner: self, userInfo: nil
        ))
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func mouseDown(with event: NSEvent) {
        NSCursor.crosshair.set()
        startPoint = convert(event.locationInWindow, from: nil)
        selectionRect = .zero
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        NSCursor.crosshair.set()
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
            log("Selection cancelled (too small).")
            NSApp.terminate(nil)
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
        log("Timed out waiting for selection.")
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
        log("Selection: \(rect)")
        Task { @MainActor in
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first(where: { $0.frame == screen.frame })
                    ?? content.displays.first else {
                    log("No display found for selection.")
                    NSApp.terminate(nil)
                    return
                }
                log("Using display: \(display.frame)")

                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = SCStreamConfiguration()
                config.width = Int(display.frame.width)
                config.height = Int(display.frame.height)
                config.showsCursor = false

                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                log("Captured image: \(image.width)x\(image.height)")

                // Convert selection (points, bottom-left, global) to pixel crop (top-left origin)
                let scale = CGFloat(image.width) / display.frame.width
                let yTop = display.frame.height - (rect.maxY - display.frame.minY)
                let cropRect = CGRect(
                    x: (rect.minX - display.frame.minX) * scale,
                    y: yTop * scale,
                    width: rect.width * scale,
                    height: rect.height * scale
                )
                log("Crop rect: \(cropRect)")
                guard let cropped = image.cropping(to: cropRect) else {
                    log("Crop failed.")
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
                    log("Copied \(text.count) chars to clipboard.")
                    print("Copied \(text.count) characters to clipboard.")
                    NSApp.terminate(nil)
                }
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true

                let handler = VNImageRequestHandler(cgImage: cropped, options: [:])
                try handler.perform([request])
            } catch {
                log("Capture failed: \(error)")
                NSApp.terminate(nil)
            }
        }
    }
}

app.run()
