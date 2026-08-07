import AppKit
import Vision
import ScreenCaptureKit

// Handles the full capture flow: permission check, overlay selection,
// screen capture, OCR, and clipboard copy. Settings-aware.
final class CaptureController: NSObject {
    static let shared = CaptureController()

    private let settings = SettingsStore.shared

    // MARK: - Public API

    func capture() {
        // 1. Permission check
        guard CGPreflightScreenCaptureAccess() else {
            requestPermission()
            return
        }

        // 2. Show the selection overlay
        showOverlay()
    }

    // MARK: - Permission

    private func requestPermission() {
        // The system TCC prompt appears automatically. Don't show our own
        // alert on top of it — that creates a confusing double popup.
        CGRequestScreenCaptureAccess()
    }

    private var overlayWindows: [NSWindow] = []
    private var escMonitor: Any?
    private var mouseMonitor: Any?
    private var dragStart: NSPoint?
    private var activeOverlay: OverlayView?

    // MARK: - Overlay

    private func showOverlay() {
        // Close any existing overlays first — otherwise a new capture stacks
        // another dim layer on top of the old one, darkening the screen.
        closeOverlays()

        let app = NSApplication.shared
        app.activate(ignoringOtherApps: true)

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
            overlay.onComplete = { [weak self] rect in
                self?.handleSelection(rect, on: screen)
            }
            window.contentView = overlay
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()

            windows.append(window)
            overlays.append(overlay)
        }

        overlayWindows = windows

        // Local event monitor catches ESC regardless of which window is key.
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC
                self?.cancelSelection()
                return nil
            }
            return event
        }

        // Drive the selection from a local mouse monitor. This bypasses app
        // activation: when the app is in the background, the first click would
        // otherwise be swallowed by activation. The monitor catches it directly.
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            self?.handleMouseEvent(event)
            return nil
        }

        // Safety timeout: close overlays if no selection within 60s.
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
            if overlays.allSatisfy({ $0.selectionRect.width == 0 }) {
                self.closeOverlays()
            }
        }
    }

    private func handleMouseEvent(_ event: NSEvent) {
        let p = event.locationInWindow
        switch event.type {
        case .leftMouseDown:
            dragStart = p
            activeOverlay = overlayWindows.first { $0.frame.contains(p) }?.contentView as? OverlayView
            activeOverlay?.startPoint = p
            activeOverlay?.selectionRect = .zero
            activeOverlay?.needsDisplay = true
        case .leftMouseDragged:
            guard let start = dragStart, let ov = activeOverlay else { return }
            ov.selectionRect = NSRect(
                x: min(start.x, p.x),
                y: min(start.y, p.y),
                width: abs(p.x - start.x),
                height: abs(p.y - start.y)
            )
            ov.needsDisplay = true
        case .leftMouseUp:
            guard let ov = activeOverlay else { return }
            if ov.selectionRect.width > 5 && ov.selectionRect.height > 5 {
                ov.onComplete?(ov.selectionRect)
            } else {
                cancelSelection()
            }
            dragStart = nil
            activeOverlay = nil
        default:
            break
        }
    }

    private func closeOverlays() {
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows = []
        if let m = escMonitor {
            NSEvent.removeMonitor(m)
            escMonitor = nil
        }
        if let m = mouseMonitor {
            NSEvent.removeMonitor(m)
            mouseMonitor = nil
        }
        dragStart = nil
        activeOverlay = nil
    }

    // Cancel the current selection (ESC or too-small click) without quitting.
    func cancelSelection() {
        closeOverlays()
    }

    private func handleSelection(_ rect: NSRect, on screen: NSScreen) {
        // Close the overlay immediately on mouse release — the capture
        // runs in the background. This gives the one-shot feel.
        closeOverlays()

        // Convert local (view) coords to global screen coords
        let globalRect = NSRect(
            x: rect.minX + screen.frame.minX,
            y: rect.minY + screen.frame.minY,
            width: rect.width,
            height: rect.height
        )

        Task { @MainActor in
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                let selCenter = CGPoint(x: globalRect.midX, y: globalRect.midY)
                guard let display = content.displays.first(where: { $0.frame.contains(selCenter) })
                    ?? content.displays.first else {
                    NSLog("No display found for selection.")
                    return
                }

                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = SCStreamConfiguration()
                config.width = Int(display.frame.width)
                config.height = Int(display.frame.height)
                config.showsCursor = false

                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

                // Convert global selection (points, bottom-left) to pixel crop (top-left origin)
                let scale = CGFloat(image.width) / display.frame.width
                let yTop = display.frame.height - (globalRect.maxY - display.frame.minY)
                let cropRect = CGRect(
                    x: (globalRect.minX - display.frame.minX) * scale,
                    y: yTop * scale,
                    width: globalRect.width * scale,
                    height: globalRect.height * scale
                )
                guard let cropped = image.cropping(to: cropRect) else {
                    NSLog("Crop failed.")
                    return
                }

                // Optional preprocessing for dark-mode OCR. We boost contrast
                // AND saturation but do NOT desaturate — grayscale collapses
                // colored text (e.g. red on dark gray) into the background.
                var ocrImage = cropped
                if settings.grayscaleContrast {
                    let ci = CIImage(cgImage: cropped)
                    let colorFilter = CIFilter(name: "CIColorControls")!
                    colorFilter.setValue(ci, forKey: kCIInputImageKey)
                    colorFilter.setValue(1.4, forKey: kCIInputSaturationKey)
                    colorFilter.setValue(1.3, forKey: kCIInputContrastKey)
                    if let out = colorFilter.outputImage {
                        let ctx = CIContext()
                        if let processed = ctx.createCGImage(out, from: out.extent) {
                            ocrImage = processed
                        }
                    }
                }

                // OCR
                let request = VNRecognizeTextRequest { [weak self] req, _ in
                    guard let observations = req.results as? [VNRecognizedTextObservation] else { return }
                    let text = Self.assembleText(from: observations)

                    if self?.settings.copyToClipboard == true {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(text, forType: .string)
                    }
                    self?.settings.lastResult = text.isEmpty ? "(no text found)" : text

                    // Toast feedback: success if we found text and copied it.
                    let copied = (self?.settings.copyToClipboard == true) && !text.isEmpty
                    if copied {
                        Toast.show(message: "Copied \(text.count) characters", success: true)
                    } else if text.isEmpty {
                        Toast.show(message: "No text found", success: false)
                    } else {
                        Toast.show(message: "Text recognized (not copied)", success: false)
                    }
                }
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true

                let handler = VNImageRequestHandler(cgImage: ocrImage, options: [:])
                try handler.perform([request])
            } catch {
                NSLog("Capture failed: \(error)")
            }
        }
    }

    // Reconstruct text from OCR observations using bounding boxes.
    //
    // Vision splits input into one observation per visual line, but it can
    // ALSO split a single line into multiple observations when words are
    // spaced apart. Joining every observation with "\n" then inserts spurious
    // blank lines. Instead: group observations by their vertical center
    // (same visual row), sort each row left-to-right, join row fragments with
    // a space, and only "\n" between distinct rows.
    private static func assembleText(from observations: [VNRecognizedTextObservation]) -> String {
        struct Row {
            var y: CGFloat
            var items: [(x: CGFloat, text: String)]
        }

        var rows: [Row] = []
        for obs in observations {
            guard let candidate = obs.topCandidates(1).first else { continue }
            let midY = obs.boundingBox.midY

            // Find an existing row whose vertical center is close to this one.
            // 0.02 (of normalized image height) tolerates Vision's per-line
            // vertical jitter between fragments of the same visual line.
            if let idx = rows.firstIndex(where: { abs($0.y - midY) < 0.02 }) {
                rows[idx].items.append((x: obs.boundingBox.minX, text: candidate.string))
            } else {
                rows.append(Row(y: midY, items: [(x: obs.boundingBox.minX, text: candidate.string)]))
            }
        }

        // Sort rows top-to-bottom (Vision boundingBox y is bottom-up, so larger
        // midY = higher on screen = earlier in the output).
        rows.sort { $0.y > $1.y }

        return rows.map { row in
            row.items.sorted { $0.x < $1.x }.map(\.text).joined(separator: " ")
        }.joined(separator: "\n")
    }
}

// MARK: - Overlay window & view

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

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

    override func mouseMoved(with event: NSEvent) { NSCursor.crosshair.set() }
    override func cursorUpdate(with event: NSEvent) { NSCursor.crosshair.set() }

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
            // Too small to be a real selection — cancel.
            CaptureController.shared.cancelSelection()
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            CaptureController.shared.cancelSelection()
        } else {
            super.keyDown(with: event)
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
