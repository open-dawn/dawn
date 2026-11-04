import Foundation
import Observation
import libdawn
import dawnLogging

@Observable
@MainActor
final class AccessibilityPermissionService {
    private let bus: any SettingsContextEventBus

    private(set) var isTrusted: Bool?
    private(set) var error: AccessibilityPermissionError?
    private(set) var isLoading = false

    init(bus: any SettingsContextEventBus) {
        self.bus = bus
    }

    func dismissError() {
        error = nil
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            isTrusted = try await fetchAccessibilityTrustStatus(using: bus)
            error = nil
        } catch {
            self.error = AccessibilityPermissionError(error)
            #log(
                "Failed to refresh Accessibility status: \(error.localizedDescription, privacy: .public)",
                level: .error,
                category: .general
            )
        }
    }

    /// Shows the Accessibility permission popup via dawnAgent.
    @discardableResult
    func promptTrust() async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            let isTrusted = try await promptAccessibilityTrust(using: bus)
            self.isTrusted = isTrusted
            error = nil
            return isTrusted
        } catch {
            self.error = AccessibilityPermissionError(error)
            #log(
                "Failed to prompt Accessibility trust: \(error.localizedDescription, privacy: .public)",
                level: .error,
                category: .general
            )
            return false
        }
    }

    func clearStatus() {
        isTrusted = nil
        error = nil
    }
}
