import Foundation
import libdawn

enum AccessibilityClient {
    static func status(json: Bool, ask: AgentAsk) async throws -> String {
        try render(
            try await trusted(.getAccessibilityStatus(GetAccessibilityStatusEvent()), ask: ask),
            json: json,
            prompting: false
        )
    }

    static func prompt(json: Bool, ask: AgentAsk) async throws -> String {
        try render(
            try await trusted(.promptAccessibilityTrust(PromptAccessibilityTrustEvent()), ask: ask),
            json: json,
            prompting: true
        )
    }

    private static func trusted(_ event: Event, ask: AgentAsk) async throws -> Bool {
        let reply = try await ask(event)

        guard case let .accessibilityStatus(payload) = reply else {
            throw AgentError.unexpectedResponse(reply.kind)
        }

        return payload.isTrusted
    }

    private static func render(_ isTrusted: Bool, json: Bool, prompting: Bool) throws -> String {
        if json {
            return try CLIJSON.encode(AccessibilityStatusEvent(isTrusted: isTrusted))
        }

        let state = isTrusted ? "trusted" : "not trusted"
        guard prompting else { return "Accessibility: \(state)" }

        return """
        Accessibility: \(state)
        This is the trust value at the time of the request, not a later choice in the system prompt.
        """
    }
}
