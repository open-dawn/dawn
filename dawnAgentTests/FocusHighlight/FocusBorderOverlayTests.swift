import AppKit
@testable import dawnAgent
import Testing

@MainActor
@Suite("FocusBorderOverlay Tests")
struct FocusBorderOverlayTests {
    @Test("show sets expanded frame and orders panel front")
    func showSetsExpandedFrameAndOrdersPanelFront() {
        let panel = FakePanel()
        let overlay = FocusBorderOverlay(panel: panel)
        let frame = CGRect(x: 40, y: 80, width: 320, height: 240)
        let expected = frame.insetBy(dx: -overlay.borderWidth, dy: -overlay.borderWidth)

        overlay.show(frame: frame)

        #expect(panel.setFrameCallCount == 1)
        #expect(panel.lastFrame == expected)
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

    @Test("show applies expanded frame size")
    func showAppliesExpandedFrameSize() {
        let panel = FakePanel()
        let overlay = FocusBorderOverlay(panel: panel)
        let frame = CGRect(x: 10, y: 20, width: 300, height: 400)
        let expectedSize = frame.insetBy(dx: -overlay.borderWidth, dy: -overlay.borderWidth).size

        overlay.show(frame: frame)

        #expect(panel.lastFrame?.size == expectedSize)
        #expect(panel.contentView?.frame.size == expectedSize)
    }

    @Test("update resizes panel")
    func updateResizesPanel() {
        let panel = FakePanel()
        let overlay = FocusBorderOverlay(panel: panel)

        overlay.show(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        overlay.update(frame: CGRect(x: 0, y: 0, width: 600, height: 500))

        let expected = CGRect(x: 0, y: 0, width: 600, height: 500)
            .insetBy(dx: -overlay.borderWidth, dy: -overlay.borderWidth)

        #expect(panel.setFrameCallCount == 2)
        #expect(panel.lastFrame == expected)
        #expect(panel.orderFrontCallCount == 2)
    }

    @Test("border styling uses configuration")
    func borderStylingUsesConfiguration() throws {
        let panel = FakePanel()
        let configuration = FocusBorderConfiguration(
            isEnabled: true,
            borderWidth: 5,
            borderColor: .systemRed,
            cornerRadius: 16
        )
        _ = FocusBorderOverlay(configuration: configuration, panel: panel)

        let contentView = try #require(panel.contentView)
        let layer = try #require(contentView.layer)

        #expect(contentView.wantsLayer)
        #expect(layer.borderWidth == configuration.borderWidth)
        #expect(layer.borderColor == configuration.borderColor.cgColor)
        #expect(layer.backgroundColor == NSColor.clear.cgColor)
        #expect(layer.isOpaque == false)
        #expect(layer.cornerRadius == configuration.cornerRadius + configuration.borderWidth)
    }

    @Test("clear window chrome is configured")
    func clearWindowChromeIsConfigured() {
        let panel = FakePanel()
        _ = FocusBorderOverlay(panel: panel)

        #expect(panel.isFloatingPanel)
        #expect(panel.hidesOnDeactivate == false)
        #expect(panel.isOpaque == false)
        #expect(panel.backgroundColor == NSColor.clear)
        #expect(panel.hasShadow == false)
        #expect(panel.level == .floating)
        #expect(panel.collectionBehavior == [.canJoinAllSpaces, .fullScreenAuxiliary])
        #expect(panel.ignoresMouseEvents)
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
        contentView?.frame = frameRect
    }

    func orderFrontRegardless() {
        orderFrontCallCount += 1
    }

    func orderOut(_: Any?) {
        orderOutCallCount += 1
    }
}
