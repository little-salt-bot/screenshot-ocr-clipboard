import AppKit
import SwiftUI

// Transient toast notification shown after a capture completes.
// Appears near the top-center of the main screen, auto-dismisses.
final class Toast {
    private static var window: NSWindow?

    static func show(message: String, success: Bool) {
        DispatchQueue.main.async {
            // Dismiss any existing toast first.
            window?.orderOut(nil)
            window = nil

            let screen = NSScreen.main ?? NSScreen.screens.first!
            let width: CGFloat = 320
            let height: CGFloat = 56

            let content = NSHostingView(rootView: ToastView(message: message, success: success))
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            win.isOpaque = false
            win.backgroundColor = .clear
            win.level = .floating
            win.ignoresMouseEvents = true
            win.contentView = content

            let x = screen.visibleFrame.midX - width / 2
            let y = screen.visibleFrame.maxY - height - 24
            win.setFrameOrigin(NSPoint(x: x, y: y))
            win.orderFrontRegardless()

            window = win

            // Auto-dismiss after 2.5s with a fade.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.3
                    win.animator().alphaValue = 0
                } completionHandler: {
                    win.orderOut(nil)
                    if window === win { window = nil }
                }
            }
        }
    }
}

// MARK: - Toast view

struct ToastView: View {
    let message: String
    let success: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(success ? .green : .orange)
                .font(.system(size: 18))
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
    }
}
