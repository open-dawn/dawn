import dawnLogging
import Foundation
import libdawn
import Observation

@Observable
@MainActor
final class AccessibilityPermissionService {
    private let bus: any SettingsContextEventBus
    private let trustPollDuration: Duration
    private let trustPollInterval: Duration

    private(set) var isTrusted: Bool?
    private(set) var error: AccessibilityPermissionError?
    private(set) var isLoading = false

    init(
        bus: any SettingsContextEventBus,
        trustPollDuration: Duration = .seconds(30),
        trustPollInterval: Duration = .milliseconds(500)
    ) {
        self.bus = bus
        self.trustPollDuration = trustPollDuration
        self.trustPollInterval = trustPollInterval
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

    @discardableResult
    func promptTrust() async -> Bool {
        isLoading = true

        do {
            // The agent shows the system prompt asynchronously. The immediate reply is the
            // pre-decision trust state (usually false) — poll until the user grants access.
            _ = try await promptAccessibilityTrust(using: bus)
            error = nil
        } catch {
            isLoading = false
            self.error = AccessibilityPermissionError(error)
            #log(
                "Failed to prompt Accessibility trust: \(error.localizedDescription, privacy: .public)",
                level: .error,
                category: .general
            )
            return false
        }

        isLoading = false

        do {
            let isTrusted = try await pollUntilTrusted()
            self.isTrusted = isTrusted
            return isTrusted
        } catch {
            self.error = AccessibilityPermissionError(error)
            #log(
                "Failed to refresh Accessibility status after prompt: \(error.localizedDescription, privacy: .public)",
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

    private func pollUntilTrusted() async throws(AccessibilityPermissionError) -> Bool {
        let deadline = ContinuousClock.now + trustPollDuration

        while true {
            let isTrusted = try await fetchAccessibilityTrustStatus(using: bus)
            if isTrusted {
                return true
            }

            if ContinuousClock.now >= deadline {
                return false
            }

            try? await Task.sleep(for: trustPollInterval)
        }
    }
}
