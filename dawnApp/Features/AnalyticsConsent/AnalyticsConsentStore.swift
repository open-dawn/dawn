import Foundation
import Observation
import libdawn

@Observable
@MainActor
final class AnalyticsConsentStore {
    static let promptCompletedKey = "app.opendawn.analytics.hasCompletedConsentPrompt"

    private let userDefaults: UserDefaults

    private(set) var isPresented = false
    private(set) var isSubmitting = false
    private(set) var errorMessage: String?

    var hasCompletedPrompt: Bool {
        userDefaults.bool(forKey: Self.promptCompletedKey)
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func presentIfNeeded(isAgentConnected: Bool, hasLoadedSettings: Bool) {
        guard isAgentConnected, hasLoadedSettings, !hasCompletedPrompt, !isPresented else {
            return
        }

        errorMessage = nil
        isPresented = true
    }

    func submit(
        analyticsEnabled: Bool,
        settingsStore: any SettingsViewStoreClient
    ) async {
        guard !isSubmitting else {
            return
        }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        var updated = settingsStore.settings
        updated.analyticsEnabled = analyticsEnabled

        do {
            try await settingsStore.updateSettings(updated)
            userDefaults.set(true, forKey: Self.promptCompletedKey)
            isPresented = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
