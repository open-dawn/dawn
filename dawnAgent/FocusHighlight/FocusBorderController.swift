import AppKit
import dawnLogging

@MainActor
protocol FocusBorderControlling {
    func start()
    func stop()
}

@MainActor
final class FocusBorderController: FocusBorderControlling {
    private var tracker: any FocusWindowTracking
    private let overlay: any FocusBorderOverlaying
    private let configuration: FocusBorderConfiguration
    private var isRunning = false

    init(
        configuration: FocusBorderConfiguration = .default,
        tracker: any FocusWindowTracking = FocusWindowTracker(),
        overlay: (any FocusBorderOverlaying)? = nil
    ) {
        self.configuration = configuration
        self.tracker = tracker
        self.overlay = overlay ?? FocusBorderOverlay(configuration: configuration)
    }

    func start() {
        guard !isRunning else { return }
        guard configuration.isEnabled else {
            #log(
                "Focus border disabled by configuration",
                level: .info,
                category: .general
            )
            return
        }

        isRunning = true

        tracker.onFocusedFrameChange = { [weak self] focused in
            self?.handleFocusedFrameChange(focused)
        }
        tracker.start()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false

        tracker.onFocusedFrameChange = nil
        tracker.stop()
        overlay.hide()
    }

    private func handleFocusedFrameChange(_ focused: FocusedWindowFrame?) {
        guard let focused else {
            overlay.hide()
            return
        }

        overlay.show(frame: focused.frame)
    }
}
