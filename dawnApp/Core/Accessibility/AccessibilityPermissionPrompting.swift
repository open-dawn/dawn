import Foundation
import libdawn

/// Asks dawnAgent to show the system Accessibility permission popup.
/// Safe to call from Settings, onboarding, or other dawnApp flows.
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

/// Asks dawnAgent whether it currently has Accessibility trust.
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
