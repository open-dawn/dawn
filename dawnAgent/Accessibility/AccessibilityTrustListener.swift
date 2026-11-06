import dawnLogging
import libdawn

@MainActor
final class AccessibilityTrustListener: Listener {
    private let trustChecker: any AccessibilityTrustChecking

    init(
        bus: EventBus,
        trustChecker: any AccessibilityTrustChecking = SystemAccessibilityTrustChecker()
    ) {
        self.trustChecker = trustChecker
        bus.addListener(
            self,
            kinds: [
                .getAccessibilityStatus,
                .promptAccessibilityTrust,
            ]
        )
    }

    func handle(_ event: Event, reply: (@Sendable (Event) -> Void)?) {
        switch event {
        case .getAccessibilityStatus:
            reply?(statusEvent())

        case .promptAccessibilityTrust:
            trustChecker.promptForTrust()
            // The system prompt is asynchronous; report the current trust state only.
            let isTrusted = trustChecker.isProcessTrusted()
            #log(
                "Accessibility trust prompt requested; current trusted=\(isTrusted)",
                level: .info,
                category: .general
            )
            reply?(.accessibilityStatus(AccessibilityStatusEvent(isTrusted: isTrusted)))

        default:
            return
        }
    }

    private func statusEvent() -> Event {
        .accessibilityStatus(
            AccessibilityStatusEvent(isTrusted: trustChecker.isProcessTrusted())
        )
    }
}
