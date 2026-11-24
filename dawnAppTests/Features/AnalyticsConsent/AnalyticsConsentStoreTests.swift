import Foundation
import Testing
import libdawn

@testable import dawnApp

@MainActor
@Suite("AnalyticsConsentStore")
struct AnalyticsConsentStoreTests {
    @Test("Presents prompt only when connected, loaded, and not yet completed")
    func presentIfNeededGuardsConditions() throws {
        let suiteName = "AnalyticsConsentStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AnalyticsConsentStore(userDefaults: defaults)

        store.presentIfNeeded(isAgentConnected: false, hasLoadedSettings: false)
        #expect(!store.isPresented)

        store.presentIfNeeded(isAgentConnected: true, hasLoadedSettings: false)
        #expect(!store.isPresented)

        store.presentIfNeeded(isAgentConnected: false, hasLoadedSettings: true)
        #expect(!store.isPresented)

        store.presentIfNeeded(isAgentConnected: true, hasLoadedSettings: true)
        #expect(store.isPresented)
    }

    @Test("Does not present prompt when already completed")
    func doesNotPresentWhenAlreadyCompleted() throws {
        let suiteName = "AnalyticsConsentStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(true, forKey: AnalyticsConsentStore.promptCompletedKey)

        let store = AnalyticsConsentStore(userDefaults: defaults)
        store.presentIfNeeded(isAgentConnected: true, hasLoadedSettings: true)

        #expect(!store.isPresented)
    }

    @Test("Submitting choice preserves existing settings, persists choice, and marks prompt completed")
    func submitPersistsChoiceAndMarksCompleted() async throws {
        let suiteName = "AnalyticsConsentStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let existing = Settings(
            launchAtLogin: true,
            showInMenuBar: false,
            forceAppsToQuit: true,
            analyticsEnabled: false,
            protectedApps: [
                ProtectedApplication(
                    bundleIdentifier: "com.apple.Safari",
                    displayName: "Safari"
                )
            ]
        )
        let client = AnalyticsConsentSettingsClientStub(settings: existing)
        let store = AnalyticsConsentStore(userDefaults: defaults)

        store.presentIfNeeded(isAgentConnected: true, hasLoadedSettings: true)
        try #require(store.isPresented)

        await store.submit(analyticsEnabled: true, settingsStore: client)

        var expected = existing
        expected.analyticsEnabled = true

        #expect(client.updatedSettings == [expected])
        #expect(!store.isPresented)
        #expect(store.hasCompletedPrompt)
        #expect(store.errorMessage == nil)
    }

    @Test("Submitting disable persists false and marks prompt completed")
    func submitDisablePersistsFalse() async throws {
        let suiteName = "AnalyticsConsentStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let existing = Settings(analyticsEnabled: true)
        let client = AnalyticsConsentSettingsClientStub(settings: existing)
        let store = AnalyticsConsentStore(userDefaults: defaults)

        store.presentIfNeeded(isAgentConnected: true, hasLoadedSettings: true)
        await store.submit(analyticsEnabled: false, settingsStore: client)

        #expect(client.updatedSettings == [Settings(analyticsEnabled: false)])
        #expect(!store.isPresented)
        #expect(store.hasCompletedPrompt)
    }

    @Test("Submission failure keeps prompt presented and exposes error message")
    func submitFailureKeepsPromptOpen() async throws {
        let suiteName = "AnalyticsConsentStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let client = AnalyticsConsentSettingsClientStub(settings: Settings())
        client.updateError = .timeout
        let store = AnalyticsConsentStore(userDefaults: defaults)

        store.presentIfNeeded(isAgentConnected: true, hasLoadedSettings: true)
        await store.submit(analyticsEnabled: true, settingsStore: client)

        #expect(store.isPresented)
        #expect(!store.hasCompletedPrompt)
        #expect(store.errorMessage == SettingsViewStoreError.timeout.localizedDescription)
    }
}

@MainActor
private final class AnalyticsConsentSettingsClientStub: SettingsViewStoreClient {
    var settings: Settings
    var error: SettingsViewStoreError?
    var updateError: SettingsViewStoreError?
    private(set) var updatedSettings: [Settings] = []

    init(settings: Settings) {
        self.settings = settings
    }

    func refresh() async {}

    func updateSettings(_ settings: Settings) async throws(SettingsViewStoreError) {
        if let updateError {
            throw updateError
        }

        self.settings = settings
        updatedSettings.append(settings)
    }
}
