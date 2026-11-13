//
//  SettingsListenerTests.swift
//  dawn
//
//  Created by Rafael Venetikides on 11/11/26.
//

import Testing
import libdawn

@testable import dawnAgent

@MainActor
@Suite("SettingsListener")
struct SettingsListenerTests {
    @Test("Settings update is rejected while preparing for update")
    func updateIsRejectedWhilePreparing() async throws {
        let settings = Settings(showInMenuBar: false)
        let provider = SettingsProviderSpy()
        let applicator = SettingsApplicatorSpy()

        let lifecycle = AgentLifecycleState()
        lifecycle.beginUpdatePreparation()

        let bus = EventBus()
        let listener = SettingsListener(
            bus: bus,
            settingsProvider: provider,
            applicator: applicator,
            lifecycle: lifecycle
        )

        let response = try await bus.ask(
            .updateSettings(UpdateSettingsEvent(settings: settings))
        )

        #expect(
            response == .settingsMutationAcknowledgement(
                .failure(failure: .updateInProgress)
            )
        )
        #expect(provider.updatedSettings.isEmpty)
        #expect(applicator.appliedSettings.isEmpty)

        _ = listener
    }

    @Test("Settings reads remain available while preparing for update")
    func readsRemainAvailableWhilePreparing() async throws {
        let expectedSettings = Settings(
            showInMenuBar: false,
            analyticsEnabled: true
        )

        let provider = SettingsProviderSpy()
        provider.settings = expectedSettings

        let lifecycle = AgentLifecycleState()
        lifecycle.beginUpdatePreparation()

        let bus = EventBus()
        let listener = SettingsListener(
            bus: bus,
            settingsProvider: provider,
            applicator: SettingsApplicatorSpy(),
            lifecycle: lifecycle
        )

        let response = try await bus.ask(
            .getSettings(GetSettingsEvent())
        )

        #expect(
            response == .settingsFetched(
                SettingsFetchedEvent(settings: expectedSettings)
            )
        )
        #expect(provider.getCallCount == 1)

        _ = listener
    }

    @Test("Apply settings is ignored while preparing for update")
    func applyIsIgnoredWhilePreparing() {
        let provider = SettingsProviderSpy()
        let applicator = SettingsApplicatorSpy()

        let lifecycle = AgentLifecycleState()
        lifecycle.beginUpdatePreparation()

        let bus = EventBus()
        let listener = SettingsListener(
            bus: bus,
            settingsProvider: provider,
            applicator: applicator,
            lifecycle: lifecycle
        )

        listener.handle(
            .applySettings(ApplySettingsEvent()),
            reply: nil
        )

        #expect(provider.getCallCount == 0)
        #expect(applicator.appliedSettings.isEmpty)
    }

    @Test("Settings update succeeds while agent is running")
    func updateSucceedsWhileRunning() async throws {
        let settings = Settings(showInMenuBar: false)
        let provider = SettingsProviderSpy()
        let applicator = SettingsApplicatorSpy()

        let bus = EventBus()
        let listener = SettingsListener(
            bus: bus,
            settingsProvider: provider,
            applicator: applicator,
            lifecycle: AgentLifecycleState()
        )

        let response = try await bus.ask(
            .updateSettings(UpdateSettingsEvent(settings: settings))
        )

        #expect(
            response == .settingsMutationAcknowledgement(.success)
        )
        #expect(provider.updatedSettings == [settings])
        #expect(applicator.appliedSettings == [settings])

        _ = listener
    }
}

@MainActor
private final class SettingsProviderSpy: SettingsProviding {
    var settings = Settings()
    var updateError: Error?

    private(set) var getCallCount = 0
    private(set) var updatedSettings: [Settings] = []

    func getSettings() async -> Settings {
        getCallCount += 1
        return settings
    }

    func updateSettings(_ settings: Settings) async throws {
        updatedSettings.append(settings)

        if let updateError {
            throw updateError
        }
    }
}

@MainActor
private final class SettingsApplicatorSpy: SettingsApplying {
    private(set) var appliedSettings: [Settings] = []

    func applySettings(_ settings: Settings) async {
        appliedSettings.append(settings)
    }
}
