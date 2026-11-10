import Foundation
import libdawn
import Testing

@Suite("AccessibilityClient")
struct AccessibilityClientTests {
    @Test("status prints whether the agent is trusted")
    func statusPrintsTrust() async throws {
        let text = try await AccessibilityClient.status(json: false) { event in
            #expect(event == .getAccessibilityStatus(GetAccessibilityStatusEvent()))
            return .accessibilityStatus(AccessibilityStatusEvent(isTrusted: true))
        }

        #expect(text == "Accessibility: trusted")
    }

    @Test("prompt reports the trust value from the moment of the ask")
    func promptReportsCurrentTrust() async throws {
        let text = try await AccessibilityClient.prompt(json: true) { event in
            #expect(event == .promptAccessibilityTrust(PromptAccessibilityTrustEvent()))
            return .accessibilityStatus(AccessibilityStatusEvent(isTrusted: false))
        }
        let decoded = try JSONDecoder().decode(AccessibilityStatusEvent.self, from: Data(text.utf8))

        #expect(decoded == AccessibilityStatusEvent(isTrusted: false))
    }

    @Test("prompt text explains that the system dialog is separate")
    func promptExplainsTheDialog() async throws {
        let text = try await AccessibilityClient.prompt(json: false) { _ in
            .accessibilityStatus(AccessibilityStatusEvent(isTrusted: false))
        }

        #expect(text == """
        Accessibility: not trusted
        This is the trust value at the time of the request, not a later choice in the system prompt.
        """)
    }
}
