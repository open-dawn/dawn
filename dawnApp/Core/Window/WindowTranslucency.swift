import AppKit
import SwiftUI

struct WindowTranslucency: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSView {
        WindowTranslucencyView()
    }

    func updateNSView(_ nsView: NSView, context _: Context) {
        (nsView as? WindowTranslucencyView)?.apply()
    }
}

private final class WindowTranslucencyView: NSView {
    override func hitTest(_: NSPoint) -> NSView? {
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
    }

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
