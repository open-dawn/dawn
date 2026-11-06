import AppKit
import ObjectiveC
import SwiftUI

struct SplitViewDividerFix: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSView {
        SplitViewDividerFixView()
    }

    func updateNSView(_ nsView: NSView, context _: Context) {
        (nsView as? SplitViewDividerFixView)?.apply()
    }
}

private final class SplitViewDividerFixView: NSView {
    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        apply()
    }

    override func layout() {
        super.layout()
        apply()
    }

    func apply() {
        guard let splitView = enclosingSplitView() else {
            return
        }

        guard object_getClass(splitView) != ZeroThicknessSplitView.self else {
            return
        }

        object_setClass(splitView, ZeroThicknessSplitView.self)
        splitView.needsLayout = true
        splitView.adjustSubviews()
    }

    private func enclosingSplitView() -> NSSplitView? {
        sequence(first: superview, next: \.?.superview)
            .compactMap { $0 as? NSSplitView }
            .first
    }
}

private final class ZeroThicknessSplitView: NSSplitView {
    override var dividerThickness: CGFloat { 0 }

    override func drawDivider(in _: NSRect) {}
}
