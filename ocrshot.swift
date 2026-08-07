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

// Borderless windows don't become key by default; we need key to get mouseMoved.
final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

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
            options: [.activeAlways, .inVisibleRect, .mouseMoved, .cursorUpdate],
            owner: self, userInfo: nil
        ))
    }

    override func mouseMoved(with event: NSEvent) {
        NSCursor.crosshair.set()
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
    let window = OverlayWindow(
        contentRect: screen.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.level = .screenSaver
    window.isOpaque = false
    window.backgroundColor = .clear
    window.ignoresMouseEvents = false
    window.acceptsMouseMovedEvents = true

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
        // rect is in the overlay view's LOCAL coords (origin = screen bottom-left).
        // Convert to global screen coords.
        let globalRect = NSRect(
            x: rect.minX + screen.frame.minX,
            y: rect.minY + screen.frame.minY,
            width: rect.width,
            height: rect.height
        )
        log("Selection local: \(rect)  global: \(globalRect)  screen: \(screen.frame)")
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

                // Convert global selection (points, bottom-left) to pixel crop (top-left origin)
                let scale = CGFloat(image.width) / display.frame.width
                let yTop = display.frame.height - (globalRect.maxY - display.frame.minY)
                let cropRect = CGRect(
                    x: (globalRect.minX - display.frame.minX) * scale,
                    y: yTop * scale,
                    width: globalRect.width * scale,
                    height: globalRect.height * scale
                )
                log("Crop rect: \(cropRect)")
                guard let cropped = image.cropping(to: cropRect) else {
                    log("Crop failed.")
                    NSApp.terminate(nil)
                    return
                }

                // Preprocess for OCR: grayscale + contrast boost.
                // Dark-mode screenshots (light text on dark bg) trip up Vision;
                // normalizing to high-contrast grayscale fixes that.
                let ci = CIImage(cgImage: cropped)
                let colorFilter = CIFilter(name: "CIColorControls")!
                colorFilter.setValue(ci, forKey: kCIInputImageKey)
                colorFilter.setValue(0.0, forKey: kCIInputSaturationKey)  // grayscale
                colorFilter.setValue(1.3, forKey: kCIInputContrastKey)     // boost contrast
                let out = colorFilter.outputImage!
                let ctx = CIContext()
                guard let processed = ctx.createCGImage(out, from: out.extent) else {
                    log("Preprocess failed.")
                    NSApp.terminate(nil)
                    return
                }
                log("Preprocessed image for OCR.")

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

                let handler = VNImageRequestHandler(cgImage: processed, options: [:])
                try handler.perform([request])
            } catch {
                log("Capture failed: \(error)")
                NSApp.terminate(nil)
            }
        }
    }
}

app.run()
