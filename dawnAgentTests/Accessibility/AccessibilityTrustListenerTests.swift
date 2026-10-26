import libdawn
import Testing

@testable import dawnAgent

@MainActor
@Suite("AccessibilityTrustListener")
struct AccessibilityTrustListenerTests {
    @Test("getAccessibilityStatus replies with current trust")
    func getStatusRepliesWithTrust() async throws {
        let bus = EventBus()
        let checker = FakeAccessibilityTrustChecker()
        checker.isTrusted = true
        let listener = AccessibilityTrustListener(bus: bus, trustChecker: checker)

        let reply = try await bus.ask(
            .getAccessibilityStatus(GetAccessibilityStatusEvent()),
            timeout: .seconds(1)
        )

        #expect(reply == .accessibilityStatus(AccessibilityStatusEvent(isTrusted: true)))
        #expect(!checker.didPrompt)
        _ = listener
    }

    @Test("promptAccessibilityTrust shows prompt and replies with result")
    func promptTrustRepliesWithResult() async throws {
        let bus = EventBus()
        let checker = FakeAccessibilityTrustChecker()
        checker.promptResult = true
        let listener = AccessibilityTrustListener(bus: bus, trustChecker: checker)

        let reply = try await bus.ask(
            .promptAccessibilityTrust(PromptAccessibilityTrustEvent()),
            timeout: .seconds(1)
        )

        #expect(checker.didPrompt)
        #expect(reply == .accessibilityStatus(AccessibilityStatusEvent(isTrusted: true)))
        _ = listener
    }
}
