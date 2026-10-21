import AppKit
import SwiftUI

/// Makes the host window transparent so the sidebar's behind-window
/// vibrancy can show the desktop through the left pane, Cursor-style.
/// The detail pane paints its own opaque background over this.
///
/// Also pins the traffic-light ("semaphore") buttons to the sidebar's
/// horizontal padding token. The buttons are system-owned and otherwise
/// keep the system inset regardless of the sidebar layout; only their
/// x origin is adjusted — vertical placement stays system-managed so
/// they remain centered on the logo row.
struct WindowTranslucency: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        WindowTranslucencyView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? WindowTranslucencyView)?.apply()
    }
}

private final class WindowTranslucencyView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observeWindowResize()
        apply()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func apply() {
        guard let window else {
            return
        }

        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.hasShadow = true
        positionTrafficLights(in: window)
    }

    /// Places the close/minimize/zoom group so its left edge follows
    /// `SidebarMetrics.horizontalPadding`, with the system 8pt spacing
    /// between buttons.
    private func positionTrafficLights(in window: NSWindow) {
        let buttons = [
            NSWindow.ButtonType.closeButton,
            .miniaturizeButton,
            .zoomButton
        ].compactMap { window.standardWindowButton($0) }

        for (index, button) in buttons.enumerated() {
            var origin = button.frame.origin
            origin.x = SidebarMetrics.horizontalPadding
                + CGFloat(index) * (button.frame.width + 8)
            button.setFrameOrigin(origin)
        }
    }

    /// The system may restore the default button positions on resize
    /// or fullscreen transitions, so re-apply after each resize.
    private func observeWindowResize() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSWindow.didResizeNotification,
            object: nil
        )

        guard let window else {
            return
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowResize),
            name: NSWindow.didResizeNotification,
            object: window
        )
    }

    @objc private func handleWindowResize() {
        DispatchQueue.main.async { [weak self] in
            self?.apply()
        }
    }
}
