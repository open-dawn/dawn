import AppKit

@MainActor
final class FocusBorderController {
    private let overlay: any FocusBorderOverlaying
    private var isRunning = false

    init(
        overlay: any FocusBorderOverlaying = FocusBorderOverlay()
    ) {
        self.overlay = overlay
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false

        overlay.hide()
    }

    // private func handleFocusedFrameChange(_: FocusedWindowFrame?) {}
}
