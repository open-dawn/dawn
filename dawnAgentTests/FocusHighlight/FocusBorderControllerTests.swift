import AppKit
@testable import dawnAgent
import Testing

@MainActor
@Suite("FocusBorderController Tests")
struct FocusBorderControllerTests {
    @Test("start forwards focused frames to overlay")
    func startForwardsFocusedFramesToOverlay() {
        let tracker = FakeFocusWindowTracker()
        let overlay = FakeFocusBorderOverlay()
        let controller = FocusBorderController(
            tracker: tracker,
            overlay: overlay
        )
        let frame = FocusedWindowFrame(
            pid: 42,
            frame: CGRect(x: 10, y: 20, width: 300, height: 200)
        )

        controller.start()
        tracker.emit(frame)

        #expect(overlay.shownFrames == [frame.frame])
        #expect(overlay.hideCallCount == 0)
    }

    @Test("nil focused frame hides overlay")
    func nilFocusedFrameHidesOverlay() {
        let tracker = FakeFocusWindowTracker()
        let overlay = FakeFocusBorderOverlay()
        let controller = FocusBorderController(
            tracker: tracker,
            overlay: overlay
        )

        controller.start()
        tracker.emit(
            FocusedWindowFrame(pid: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        )
        tracker.emit(nil)

        #expect(overlay.hideCallCount == 1)
    }

    @Test("stop hides overlay and stops tracker")
    func stopHidesOverlayAndStopsTracker() {
        let tracker = FakeFocusWindowTracker()
        let overlay = FakeFocusBorderOverlay()
        let controller = FocusBorderController(
            tracker: tracker,
            overlay: overlay
        )

        controller.start()
        controller.stop()

        #expect(tracker.stopCallCount == 1)
        #expect(overlay.hideCallCount == 1)
        #expect(tracker.onFocusedFrameChange == nil)
    }

    @Test("disabled configuration does not start tracker")
    func disabledConfigurationDoesNotStartTracker() {
        let tracker = FakeFocusWindowTracker()
        let overlay = FakeFocusBorderOverlay()
        var configuration = FocusBorderConfiguration.default
        configuration.isEnabled = false

        let controller = FocusBorderController(
            configuration: configuration,
            tracker: tracker,
            overlay: overlay
        )

        controller.start()

        #expect(tracker.startCallCount == 0)
        #expect(overlay.shownFrames.isEmpty)
    }

    @Test("start is idempotent")
    func startIsIdempotent() {
        let tracker = FakeFocusWindowTracker()
        let overlay = FakeFocusBorderOverlay()
        let controller = FocusBorderController(
            tracker: tracker,
            overlay: overlay
        )

        controller.start()
        controller.start()

        #expect(tracker.startCallCount == 1)
    }
}

@MainActor
private final class FakeFocusWindowTracker: FocusWindowTracking {
    var onFocusedFrameChange: ((FocusedWindowFrame?) -> Void)?
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0

    func start() {
        startCallCount += 1
    }

    func stop() {
        stopCallCount += 1
    }

    func emit(_ frame: FocusedWindowFrame?) {
        onFocusedFrameChange?(frame)
    }
}

@MainActor
private final class FakeFocusBorderOverlay: FocusBorderOverlaying {
    private(set) var shownFrames: [CGRect] = []
    private(set) var hideCallCount = 0

    func show(frame: CGRect) {
        shownFrames.append(frame)
    }

    func update(frame: CGRect) {
        show(frame: frame)
    }

    func hide() {
        hideCallCount += 1
    }
}
