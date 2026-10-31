import Foundation
import Testing
import libdawn

@testable import dawnApp

@MainActor
@Suite("SettingsViewStore")
struct SettingsViewStoreTests {
    @Test("Start registers once for available settings")
    func startRegistersOnce() {
        let bus = SettingsEventBusSpy()
        let store = SettingsViewStore(bus: bus)

        store.start()
        store.start()

        #expect(bus.addedListeners.count == 1)
        #expect(bus.addedListeners.first === store)
        #expect(bus.addedKinds.first == Set([EventKind.availableSettings]))
    }

    @Test("Stop removes a started store")
    func stopRemovesListener() {
        let bus = SettingsEventBusSpy()
        let store = SettingsViewStore(bus: bus)

        store.start()
        store.stop()
        store.stop()

        #expect(bus.removedListeners.count == 1)
        #expect(bus.removedListeners.first === store)
    }

    @Test("Available settings replaces the complete snapshot")
    func availableSettingsReplacesSnapshot() {
        let bus = SettingsEventBusSpy()
        let store = SettingsViewStore(bus: bus)
        let first = Settings(launchAtLogin: true)
        let second = Settings(showInMenuBar: false, analyticsEnabled: true)

        store.handle(
            .availableSettings(AvailableSettingsEvent(settings: first)),
            reply: nil
        )
        store.handle(
            .availableSettings(AvailableSettingsEvent(settings: second)),
            reply: nil
        )

        #expect(store.settings == second)
        #expect(store.error == nil)
    }

    @Test("Refresh asks for and stores settings")
    func refreshStoresSettings() async {
        let settings = Settings(
            launchAtLogin: true,
            forceAppsToQuit: true
        )
        let bus = SettingsEventBusSpy()
        bus.askResponse = .settingsFetched(SettingsFetchedEvent(settings: settings))

        let store = SettingsViewStore(bus: bus)
        await store.refresh()

        #expect(bus.askedEvents == [.getSettings(GetSettingsEvent())])
        #expect(bus.requestedTimeouts == [.seconds(5)])
        #expect(store.settings == settings)
        #expect(store.error == nil)
        #expect(!store.isLoading)
    }

    @Test("Refresh reports an unexpected response")
    func refreshReportsUnexpectedResponse() async {
        let bus = SettingsEventBusSpy()
        bus.askResponse = .debugPong(DebugPongEvent(message: "unexpected"))

        let store = SettingsViewStore(bus: bus)
        await store.refresh()

        #expect(store.settings == Settings())
        #expect(store.error == .unexpectedResponse(.debugPong))
        #expect(!store.isLoading)
    }

    @Test("Refresh maps transport timeout")
    func refreshMapsTimeout() async {
        let bus = SettingsEventBusSpy()
        bus.askError = EventAskError.timeout

        let store = SettingsViewStore(bus: bus)
        await store.refresh()

        #expect(store.error == .timeout)
        #expect(!store.isLoading)
    }

    @Test("Update settings asks and stores the saved value")
    func updateSettingsStoresValue() async throws {
        let settings = Settings(
            launchAtLogin: true,
            analyticsEnabled: true
        )
        let bus = SettingsEventBusSpy()
        bus.askResponse = .settingsMutationAcknowledgement(.success)

        let store = SettingsViewStore(bus: bus)
        try await store.updateSettings(settings)

        #expect(
            bus.askedEvents == [
                .updateSettings(UpdateSettingsEvent(settings: settings))
            ]
        )
        #expect(bus.requestedTimeouts == [.seconds(5)])
        #expect(store.settings == settings)
        #expect(store.error == nil)
    }

    @Test("Update settings records validation failure")
    func updateSettingsRecordsValidationFailure() async {
        let bus = SettingsEventBusSpy()
        bus.askResponse = .settingsMutationAcknowledgement(
            .failure(failure: .emptyApplicationBundleIdentifier)
        )

        let store = SettingsViewStore(bus: bus)
        let expectedError = SettingsViewStoreError.mutationRejected(
            .emptyApplicationBundleIdentifier
        )

        await #expect(throws: expectedError) {
            try await store.updateSettings(
                Settings(
                    protectedApps: [
                        ProtectedApplication(
                            bundleIdentifier: " ",
                            displayName: "Safari"
                        )
                    ]
                )
            )
        }

        #expect(store.settings == Settings())
        #expect(store.error == expectedError)
    }

    @Test("Update settings reports an unexpected response")
    func updateSettingsReportsUnexpectedResponse() async {
        let bus = SettingsEventBusSpy()
        bus.askResponse = .debugPong(DebugPongEvent(message: "unexpected"))

        let store = SettingsViewStore(bus: bus)
        let expectedError = SettingsViewStoreError.unexpectedResponse(.debugPong)

        await #expect(throws: expectedError) {
            try await store.updateSettings(Settings(launchAtLogin: true))
        }

        #expect(store.error == expectedError)
    }

    @Test("Dismiss error clears the current error")
    func dismissErrorClearsCurrentError() async throws {
        let bus = SettingsEventBusSpy()
        bus.askError = EventAskError.timeout

        let store = SettingsViewStore(bus: bus)
        await store.refresh()

        try #require(store.error == .timeout)

        store.dismissError()

        #expect(store.error == nil)
    }
}

@MainActor
private final class SettingsEventBusSpy: SettingsEventBus {
    private(set) var addedListeners: [Listener] = []
    private(set) var addedKinds: [Set<EventKind>?] = []
    private(set) var removedListeners: [Listener] = []
    private(set) var askedEvents: [Event] = []
    private(set) var requestedTimeouts: [Duration] = []

    var askResponse: Event = .settingsFetched(SettingsFetchedEvent(settings: Settings()))
    var askError: Error?

    func addListener(_ listener: any Listener, kinds: Set<EventKind>?) {
        addedListeners.append(listener)
        addedKinds.append(kinds)
    }

    func removeListener(_ listener: any Listener) {
        removedListeners.append(listener)
    }

    func ask(_ event: Event, timeout: Duration) async throws -> Event {
        askedEvents.append(event)
        requestedTimeouts.append(timeout)

        if let askError {
            throw askError
        }

        return askResponse
    }
}
