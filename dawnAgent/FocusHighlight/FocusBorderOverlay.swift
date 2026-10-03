import AppKit

@MainActor
protocol FocusBorderOverlaying {
    func show(frame: CGRect)
    func update(frame: CGRect)
    func hide()
}

@MainActor
protocol BorderPanel {
    var isFloatingPanel: Bool { get set }
    var hidesOnDeactivate: Bool { get set }
    var isOpaque: Bool { get set }
    var backgroundColor: NSColor! { get set }
    var hasShadow: Bool { get set }
    var level: NSWindow.Level { get set }
    var collectionBehavior: NSWindow.CollectionBehavior { get set }
    var ignoresMouseEvents: Bool { get set }
    var contentView: NSView? { get set }

    func setFrame(_ frameRect: NSRect, display flag: Bool)
    func orderFrontRegardless()
    func orderOut(_ sender: Any?)
}

extension NSPanel: BorderPanel {}

@MainActor
final class FocusBorderOverlay: FocusBorderOverlaying {
    private var panel: any BorderPanel
    let borderWidth: CGFloat = 2.0

    init(
        panel: any BorderPanel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
    ) {
        self.panel = panel
        prepareFloatingOverlay()
        prepareBorder()
    }

    func show(frame: CGRect) {
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
    }

    func update(frame: CGRect) {
        show(frame: frame)
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func prepareFloatingOverlay() {
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true
    }

    private func prepareBorder() {
        let border = NSView(frame: NSRect())
        border.wantsLayer = true
        border.layer?.isOpaque = false
        border.layer?.backgroundColor = NSColor.clear.cgColor
        border.layer?.borderColor = NSColor.blue.cgColor
        border.layer?.borderWidth = borderWidth

        panel.contentView = border
    }
}
