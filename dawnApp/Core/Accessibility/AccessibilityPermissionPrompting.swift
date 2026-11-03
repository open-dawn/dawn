import Foundation
import libdawn

@MainActor
@discardableResult
func promptAccessibilityTrust(
    using bus: any SettingsContextEventBus,
    timeout: Duration = .seconds(5)
) async throws(AccessibilityPermissionError) -> Bool {
    let response: Event
    do {
        response = try await bus.ask(
            .promptAccessibilityTrust(PromptAccessibilityTrustEvent()),
            timeout: timeout
        )
    } catch {
        throw AccessibilityPermissionError(error)
    }

    guard case let .accessibilityStatus(payload) = response else {
        throw .unexpectedResponse(response.kind)
    }

    return payload.isTrusted
}

@MainActor
func fetchAccessibilityTrustStatus(
    using bus: any SettingsContextEventBus,
    timeout: Duration = .seconds(5)
) async throws(AccessibilityPermissionError) -> Bool {
    let response: Event
    do {
        response = try await bus.ask(
            .getAccessibilityStatus(GetAccessibilityStatusEvent()),
            timeout: timeout
        )
    } catch {
        throw AccessibilityPermissionError(error)
    }

    guard case let .accessibilityStatus(payload) = response else {
        throw .unexpectedResponse(response.kind)
    }

    return payload.isTrusted
}
