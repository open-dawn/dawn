import AppKit
@testable import dawnAgent
import Testing

@MainActor
@Suite("FocusBorderOverlay Tests")
struct FocusBorderOverlayTests {
    @Test("show sets frame and orders panel front")
    func showSetsFrameAndOrdersPanelFront() {
        let panel = FakePanel()
        let overlay = FocusBorderOverlay(panel: panel)
        let frame = CGRect(x: 40, y: 80, width: 320, height: 240)

        overlay.show(frame: frame)

        #expect(panel.setFrameCallCount == 1)
        #expect(panel.lastFrame == frame)
        #expect(panel.lastDisplayFlag == true)
        #expect(panel.orderFrontCallCount == 1)
    }

    @Test("hide dismisses panel")
    func hideDismissesPanel() {
        let panel = FakePanel()
        let overlay = FocusBorderOverlay(panel: panel)

        overlay.show(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        overlay.hide()

        #expect(panel.orderOutCallCount == 1)
    }

    @Test("show applies frame size")
    func showAppliesFrameSize() {
        let panel = FakePanel()
        let overlay = FocusBorderOverlay(panel: panel)
        let frame = CGRect(x: 10, y: 20, width: 300, height: 400)

        overlay.show(frame: frame)

        #expect(panel.lastFrame?.size == frame.size)
        #expect(panel.contentView?.frame.size == frame.size)
    }

    @Test("update resizes panel")
    func updateResizesPanel() {
        let panel = FakePanel()
        let overlay = FocusBorderOverlay(panel: panel)

        overlay.show(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        overlay.update(frame: CGRect(x: 0, y: 0, width: 600, height: 500))

        #expect(panel.setFrameCallCount == 2)
        #expect(panel.lastFrame?.size == CGSize(width: 600, height: 500))
        #expect(panel.orderFrontCallCount == 2)
    }

    @Test("border styling is configured")
    func borderStylingIsConfigured() throws {
        let panel = FakePanel()
        let overlay = FocusBorderOverlay(panel: panel)

        let contentView = try #require(panel.contentView)
        let layer = try #require(contentView.layer)

        #expect(contentView.wantsLayer)
    }

    @Test("hide is idempotent")
    func hideIsIdempotent() {
        let panel = FakePanel()
        let overlay = FocusBorderOverlay(panel: panel)

        overlay.hide()
        overlay.hide()

        #expect(panel.orderOutCallCount == 2)
    }
}

@MainActor
final class FakePanel: BorderPanel {
    var isFloatingPanel: Bool = false
    var hidesOnDeactivate: Bool = true
    var isOpaque: Bool = true
    var backgroundColor: NSColor! = .red
    var hasShadow: Bool = true
    var level: NSWindow.Level = .normal
    var collectionBehavior: NSWindow.CollectionBehavior = []
    var ignoresMouseEvents: Bool = false
    var contentView: NSView?

    private(set) var setFrameCallCount = 0
    private(set) var orderFrontCallCount = 0
    private(set) var orderOutCallCount = 0
    private(set) var lastFrame: NSRect?
    private(set) var lastDisplayFlag: Bool?

    func setFrame(_ frameRect: NSRect, display flag: Bool) {
        setFrameCallCount += 1
        lastFrame = frameRect
        lastDisplayFlag = flag
        // Mimic NSWindow resizing its content view with the panel frame.
        contentView?.frame = frameRect
    }

    func orderFrontRegardless() {
        orderFrontCallCount += 1
    }

    func orderOut(_: Any?) {
        orderOutCallCount += 1
    }
}
