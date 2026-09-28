//
//  SettingsContextStoreTests.swift
//  dawn
//
//  Created by Rafael Venetikides on 22/09/26.
//

import Foundation
import libdawn
import Testing

@testable import dawnApp

@MainActor
@Suite("SettingsContextStore")
struct SettingsContextStoreTests {
    @Test("Start registers once for available contexts")
    func startRegistersOnce() async throws {
        let bus = ContextEventBusSpy()
        let store = SettingsContextStore(bus: bus)

        store.start()
        store.start()

        #expect(bus.addedListeners.count == 1)
        #expect(bus.addedListeners.first === store)
        #expect(bus.addedKinds.first == Set([EventKind.availableContexts]))
    }

    @Test("Stop removes a started store")
    func stopRemovesListener() async throws {
        let bus = ContextEventBusSpy()
        let store = SettingsContextStore(bus: bus)

        store.start()
        store.stop()
        store.stop()

        #expect(bus.removedListeners.count == 1)
        #expect(bus.removedListeners.first === store)
    }

    @Test("Available contexts replaces the complete snapshot")
    func availableContextsReplacesSnapshot() {
        let bus = ContextEventBusSpy()
        let store = SettingsContextStore(bus: bus)

        let first = WorkspaceContext(
            name: "First",
            symbol: "1.circle"
        )
        let second = WorkspaceContext(
            name: "Second",
            symbol: "2.circle"
        )

        store.handle(
            .availableContexts(
                AvailableContextsEvent(contexts: [first])
            ),
            reply: nil
        )

        store.handle(
            .availableContexts(
                AvailableContextsEvent(contexts: [second])
            ),
            reply: nil
        )

        #expect(store.contexts == [second])
    }

    @Test("Refresh asks for and stores available contexts")
    func refreshStoresContexts() async {
        let context = WorkspaceContext(
            name: "Work",
            symbol: "briefcase"
        )

        let bus = ContextEventBusSpy()
        bus.askResponse = .contextsFetched(
            ContextsFetchedEvent(contexts: [context])
        )

        let store = SettingsContextStore(bus: bus)

        await store.refresh()

        #expect(
            bus.askedEvents == [
                .getContexts(GetContextsEvent())
            ]
        )
        #expect(bus.requestedTimeouts == [.seconds(5)])
        #expect(store.contexts == [context])
        #expect(store.error == nil)
        #expect(!store.isLoading)
    }

    @Test("Refresh reports an unexpected response")
    func refreshReportsUnexpectedResponse() async {
        let bus = ContextEventBusSpy()
        bus.askResponse = .debugPong(
            DebugPongEvent(message: "unexpected")
        )

        let store = SettingsContextStore(bus: bus)

        await store.refresh()

        #expect(store.contexts.isEmpty)
        #expect(store.error == .unexpectedResponse(.debugPong))
        #expect(!store.isLoading)
    }

    @Test("Refresh maps transport errors")
    func refreshMapsTransportError() async {
        let bus = ContextEventBusSpy()
        bus.askError = EventRemoteError.notConnected

        let store = SettingsContextStore(bus: bus)

        await store.refresh()

        #expect(store.error == .notConnected)
        #expect(!store.isLoading)
    }

    @Test("Mutation commands send the expected requests")
    func mutationCommandsSendExpectedRequests() async throws {
        let existingContext = WorkspaceContext(
            name: "Existing",
            symbol: "folder"
        )
        let application = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari"
        )

        let createdID = UUID()
        let updatedContext = WorkspaceContext(
            name: "Updated",
            symbol: "briefcase",
            applications: [application]
        )
        let deletedID = UUID()
        let switchedID = UUID()

        let bus = ContextEventBusSpy()
        let store = SettingsContextStore(bus: bus)

        store.handle(
            .availableContexts(
                AvailableContextsEvent(contexts: [existingContext])
            ),
            reply: nil
        )

        bus.askResponse = .contextMutationAcknowledged(
            .success(contextID: createdID)
        )

        let returnedID = try await store.createContext(
            name: "Created",
            symbol: "star",
            applications: [application]
        )

        bus.askResponse = .contextMutationAcknowledged(
            .success(contextID: updatedContext.id)
        )
        try await store.updateContext(updatedContext)

        bus.askResponse = .contextMutationAcknowledged(
            .success(contextID: deletedID)
        )
        try await store.deleteContext(id: deletedID)

        bus.askResponse = .contextMutationAcknowledged(
            .success(contextID: switchedID)
        )
        try await store.switchContext(id: switchedID)

        #expect(returnedID == createdID)

        #expect(
            bus.askedEvents == [
                .createContext(
                    CreateContextEvent(
                        name: "Created",
                        symbol: "star",
                        applications: [application]
                    )
                ),
                .updateContext(
                    UpdateContextEvent(context: updatedContext)
                ),
                .deleteContext(
                    DeleteContextEvent(contextID: deletedID)
                ),
                .switchContext(
                    SwitchContextEvent(contextID: switchedID)
                ),
            ]
        )

        #expect(
            bus.requestedTimeouts == [
                .seconds(5),
                .seconds(5),
                .seconds(5),
                .seconds(5),
            ]
        )

        #expect(store.contexts == [existingContext])
        #expect(store.error == nil)
    }

    @Test("Mutation failure acknowledgement is exposed")
    func mutationFailureIsExposed() async {
        let bus = ContextEventBusSpy()
        bus.askResponse = .contextMutationAcknowledged(
            .failure(failure: .emptyContextName)
        )

        let store = SettingsContextStore(bus: bus)
        let expectedError = SettingsContextStoreError.mutationRejected(
            .emptyContextName
        )

        await #expect(throws: expectedError) {
            _ = try await store.createContext(
                name: "",
                symbol: "star",
                applications: []
            )
        }

        #expect(store.error == expectedError)
    }

    @Test("Mutation reports an unexpected response")
    func mutationReportsUnexpectedResponse() async {
        let bus = ContextEventBusSpy()
        bus.askResponse = .debugPong(
            DebugPongEvent(message: "unexpected")
        )

        let store = SettingsContextStore(bus: bus)
        let expectedError = SettingsContextStoreError.unexpectedResponse(
            .debugPong
        )

        await #expect(throws: expectedError) {
            _ = try await store.createContext(
                name: "Work",
                symbol: "briefcase",
                applications: []
            )
        }

        #expect(store.error == expectedError)
    }

    @Test("Mutation rejects an acknowledgement for another context")
    func mutationRejectsMismatchedContextIdentifier() async {
        let requestedID = UUID()
        let acknowledgedID = UUID()

        let bus = ContextEventBusSpy()
        bus.askResponse = .contextMutationAcknowledged(
            .success(contextID: acknowledgedID)
        )

        let store = SettingsContextStore(bus: bus)
        let expectedError =
            SettingsContextStoreError.contextIdentifierMismatch(
                expected: requestedID,
                received: acknowledgedID
            )

        await #expect(throws: expectedError) {
            try await store.deleteContext(id: requestedID)
        }

        #expect(store.error == expectedError)
    }

    @Test("Mutation maps transport errors")
    func mutationMapsTransportError() async {
        let bus = ContextEventBusSpy()
        bus.askError = EventRemoteError.notConnected

        let store = SettingsContextStore(bus: bus)

        await #expect(throws: SettingsContextStoreError.notConnected) {
            try await store.switchContext(id: UUID())
        }

        #expect(store.error == .notConnected)
    }

    @Test("Dismiss error clears the current error")
    func dismissErrorClearsCurrentError() async throws {
        let bus = ContextEventBusSpy()
        bus.askError = EventRemoteError.notConnected

        let store = SettingsContextStore(bus: bus)

        await store.refresh()

        try #require(store.error == .notConnected)

        store.dismissError()

        #expect(store.error == nil)
    }
}

@MainActor
private final class ContextEventBusSpy: SettingsContextEventBus {
    private(set) var addedListeners: [Listener] = []
    private(set) var addedKinds: [Set<EventKind>?] = []
    private(set) var removedListeners: [Listener] = []
    private(set) var askedEvents: [Event] = []
    private(set) var requestedTimeouts: [Duration] = []

    var askResponse: Event = .contextsFetched(
        ContextsFetchedEvent(contexts: [])
    )
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
