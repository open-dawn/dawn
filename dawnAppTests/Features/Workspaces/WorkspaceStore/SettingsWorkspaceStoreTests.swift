//
//  SettingsWorkspaceStoreTests.swift
//  dawn
//
//  Created by Rafael Venetikides on 22/09/26.
//

import Foundation
import libdawn
import Testing

@testable import dawnApp

@MainActor
@Suite("SettingsWorkspaceStore")
struct SettingsWorkspaceStoreTests {
    @Test("Start registers once for available workspaces")
    func startRegistersOnce() async throws {
        let bus = WorkspaceEventBusSpy()
        let store = SettingsWorkspaceStore(bus: bus)

        store.start()
        store.start()

        #expect(bus.addedListeners.count == 1)
        #expect(bus.addedListeners.first === store)
        #expect(bus.addedKinds.first == Set([EventKind.availableWorkspaces]))
    }

    @Test("Stop removes a started store")
    func stopRemovesListener() async throws {
        let bus = WorkspaceEventBusSpy()
        let store = SettingsWorkspaceStore(bus: bus)

        store.start()
        store.stop()
        store.stop()

        #expect(bus.removedListeners.count == 1)
        #expect(bus.removedListeners.first === store)
    }

    @Test("Available workspaces replaces the complete snapshot")
    func availableWorkspacesReplacesSnapshot() {
        let bus = WorkspaceEventBusSpy()
        let store = SettingsWorkspaceStore(bus: bus)

        let first = Workspace(
            name: "First",
            symbol: "1.circle"
        )
        let second = Workspace(
            name: "Second",
            symbol: "2.circle"
        )
        var active = WorkspaceActivityState.empty
        active.activate(
            workspaceID: first.id,
            at: Date(timeIntervalSince1970: 100)
        )

        store.handle(
            .availableWorkspaces(
                AvailableWorkspacesEvent(
                    workspaces: [first],
                    activity: active
                )
            ),
            reply: nil
        )

        #expect(store.activity.activeWorkspaceID == first.id)

        store.handle(
            .availableWorkspaces(
                AvailableWorkspacesEvent(workspaces: [second])
            ),
            reply: nil
        )

        #expect(store.workspaces == [second])
        #expect(store.activity.activeWorkspaceID == nil)
    }

    @Test("Available workspaces snapshot keeps archived workspaces in the same list")
    func availableWorkspacesSnapshotIncludesArchivedWorkspaces() {
        let bus = WorkspaceEventBusSpy()
        let store = SettingsWorkspaceStore(bus: bus)
        let active = Workspace(name: "Work", symbol: "briefcase")
        let archived = Workspace(
            name: "Old",
            symbol: "archivebox",
            isArchived: true
        )

        store.handle(
            .availableWorkspaces(
                AvailableWorkspacesEvent(workspaces: [active, archived])
            ),
            reply: nil
        )

        #expect(store.workspaces == [active, archived])

        store.handle(
            .availableWorkspaces(
                AvailableWorkspacesEvent(workspaces: [active])
            ),
            reply: nil
        )

        #expect(store.workspaces == [active])
    }

    @Test("Refresh asks for and stores available workspaces")
    func refreshStoresWorkspaces() async {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )
        var activity = WorkspaceActivityState.empty
        activity.activate(
            workspaceID: workspace.id,
            at: Date(timeIntervalSince1970: 100)
        )

        let bus = WorkspaceEventBusSpy()
        bus.askResponse = .workspacesFetched(
            WorkspacesFetchedEvent(
                workspaces: [workspace],
                activity: activity
            )
        )

        let store = SettingsWorkspaceStore(bus: bus)

        await store.refresh()

        #expect(
            bus.askedEvents == [
                .getWorkspaces(GetWorkspacesEvent())
            ]
        )
        #expect(bus.requestedTimeouts == [.seconds(5)])
        #expect(store.workspaces == [workspace])
        #expect(store.activity == activity)
        #expect(store.error == nil)
        #expect(!store.isLoading)
    }

    @Test("Refresh stores archived workspaces in the same list")
    func refreshStoresArchivedWorkspaces() async {
        let active = Workspace(name: "Work", symbol: "briefcase")
        let archived = Workspace(
            name: "Old",
            symbol: "archivebox",
            isArchived: true
        )

        let bus = WorkspaceEventBusSpy()
        bus.askResponse = .workspacesFetched(
            WorkspacesFetchedEvent(workspaces: [active, archived])
        )

        let store = SettingsWorkspaceStore(bus: bus)

        await store.refresh()

        #expect(store.workspaces == [active, archived])
        #expect(store.error == nil)
    }

    @Test("Refresh reports an unexpected response")
    func refreshReportsUnexpectedResponse() async {
        let bus = WorkspaceEventBusSpy()
        bus.askResponse = .debugPong(
            DebugPongEvent(message: "unexpected")
        )

        let store = SettingsWorkspaceStore(bus: bus)

        await store.refresh()

        #expect(store.workspaces.isEmpty)
        #expect(store.error == .unexpectedResponse(.debugPong))
        #expect(!store.isLoading)
    }

    @Test("Refresh maps transport errors")
    func refreshMapsTransportError() async {
        let bus = WorkspaceEventBusSpy()
        bus.askError = EventRemoteError.notConnected

        let store = SettingsWorkspaceStore(bus: bus)

        await store.refresh()

        #expect(store.error == .notConnected)
        #expect(!store.isLoading)
    }

    @Test("Mutation commands send the expected requests")
    func mutationCommandsSendExpectedRequests() async throws {
        let existingWorkspace = Workspace(
            name: "Existing",
            symbol: "folder"
        )
        let application = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari"
        )

        let createdID = UUID()
        let updatedWorkspace = Workspace(
            name: "Updated",
            symbol: "briefcase",
            applications: [application]
        )
        let deletedID = UUID()
        let switchedID = UUID()

        let bus = WorkspaceEventBusSpy()
        let store = SettingsWorkspaceStore(bus: bus)

        store.handle(
            .availableWorkspaces(
                AvailableWorkspacesEvent(workspaces: [existingWorkspace])
            ),
            reply: nil
        )

        bus.askResponse = .workspaceMutationAcknowledged(
            .success(workspaceID: createdID)
        )

        let returnedID = try await store.createWorkspace(
            name: "Created",
            symbol: "star",
            applications: [application]
        )

        bus.askResponse = .workspaceMutationAcknowledged(
            .success(workspaceID: updatedWorkspace.id)
        )
        try await store.updateWorkspace(updatedWorkspace)

        bus.askResponse = .workspaceMutationAcknowledged(
            .success(workspaceID: deletedID)
        )
        try await store.deleteWorkspace(id: deletedID)

        bus.askResponse = .workspaceMutationAcknowledged(
            .success(workspaceID: switchedID)
        )
        try await store.switchWorkspace(id: switchedID)

        #expect(returnedID == createdID)

        #expect(
            bus.askedEvents == [
                .createWorkspace(
                    CreateWorkspaceEvent(
                        name: "Created",
                        symbol: "star",
                        applications: [application]
                    )
                ),
                .updateWorkspace(
                    UpdateWorkspaceEvent(workspace: updatedWorkspace)
                ),
                .deleteWorkspace(
                    DeleteWorkspaceEvent(workspaceID: deletedID)
                ),
                .switchWorkspace(
                    SwitchWorkspaceEvent(workspaceID: switchedID)
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

        #expect(store.workspaces == [existingWorkspace])
        #expect(store.error == nil)
    }

    @Test("Stop sends the expected request")
    func stopSendsExpectedRequest() async throws {
        let workspaceID = UUID()
        let bus = WorkspaceEventBusSpy()
        bus.askResponse = .workspaceMutationAcknowledged(
            .success(workspaceID: workspaceID)
        )
        let store = SettingsWorkspaceStore(bus: bus)

        try await store.stopWorkspace(id: workspaceID)

        #expect(
            bus.askedEvents == [
                .stopWorkspace(StopWorkspaceEvent(workspaceID: workspaceID))
            ]
        )
        #expect(bus.requestedTimeouts == [.seconds(5)])
        #expect(store.error == nil)
    }

    @Test("Archive and unarchive send the expected requests")
    func archiveCommandsSendExpectedRequests() async throws {
        let archivedID = UUID()
        let restoredID = UUID()
        let bus = WorkspaceEventBusSpy()
        let store = SettingsWorkspaceStore(bus: bus)

        bus.askResponse = .workspaceMutationAcknowledged(
            .success(workspaceID: archivedID)
        )
        try await store.archiveWorkspace(id: archivedID)

        bus.askResponse = .workspaceMutationAcknowledged(
            .success(workspaceID: restoredID)
        )
        try await store.unarchiveWorkspace(id: restoredID)

        #expect(
            bus.askedEvents == [
                .archiveWorkspace(ArchiveWorkspaceEvent(workspaceID: archivedID)),
                .unarchiveWorkspace(UnarchiveWorkspaceEvent(workspaceID: restoredID)),
            ]
        )
        #expect(bus.requestedTimeouts == [.seconds(5), .seconds(5)])
        #expect(store.error == nil)
    }

    @Test("Mutation failure acknowledgement is exposed")
    func mutationFailureIsExposed() async {
        let bus = WorkspaceEventBusSpy()
        bus.askResponse = .workspaceMutationAcknowledged(
            .failure(failure: .emptyWorkspaceName)
        )

        let store = SettingsWorkspaceStore(bus: bus)
        let expectedError = SettingsWorkspaceStoreError.mutationRejected(
            .emptyWorkspaceName
        )

        await #expect(throws: expectedError) {
            _ = try await store.createWorkspace(
                name: "",
                symbol: "star",
                applications: []
            )
        }

        #expect(store.error == expectedError)
    }

    @Test("Mutation reports an unexpected response")
    func mutationReportsUnexpectedResponse() async {
        let bus = WorkspaceEventBusSpy()
        bus.askResponse = .debugPong(
            DebugPongEvent(message: "unexpected")
        )

        let store = SettingsWorkspaceStore(bus: bus)
        let expectedError = SettingsWorkspaceStoreError.unexpectedResponse(
            .debugPong
        )

        await #expect(throws: expectedError) {
            _ = try await store.createWorkspace(
                name: "Work",
                symbol: "briefcase",
                applications: []
            )
        }

        #expect(store.error == expectedError)
    }

    @Test("Mutation rejects an acknowledgement for another workspace")
    func mutationRejectsMismatchedWorkspaceIdentifier() async {
        let requestedID = UUID()
        let acknowledgedID = UUID()

        let bus = WorkspaceEventBusSpy()
        bus.askResponse = .workspaceMutationAcknowledged(
            .success(workspaceID: acknowledgedID)
        )

        let store = SettingsWorkspaceStore(bus: bus)
        let expectedError =
            SettingsWorkspaceStoreError.workspaceIdentifierMismatch(
                expected: requestedID,
                received: acknowledgedID
            )

        await #expect(throws: expectedError) {
            try await store.deleteWorkspace(id: requestedID)
        }

        #expect(store.error == expectedError)
    }

    @Test("Mutation maps transport errors")
    func mutationMapsTransportError() async {
        let bus = WorkspaceEventBusSpy()
        bus.askError = EventRemoteError.notConnected

        let store = SettingsWorkspaceStore(bus: bus)

        await #expect(throws: SettingsWorkspaceStoreError.notConnected) {
            try await store.switchWorkspace(id: UUID())
        }

        #expect(store.error == .notConnected)
    }

    @Test("Dismiss error clears the current error")
    func dismissErrorClearsCurrentError() async throws {
        let bus = WorkspaceEventBusSpy()
        bus.askError = EventRemoteError.notConnected

        let store = SettingsWorkspaceStore(bus: bus)

        await store.refresh()

        try #require(store.error == .notConnected)

        store.dismissError()

        #expect(store.error == nil)
    }
}

@MainActor
private final class WorkspaceEventBusSpy: SettingsEventBus {
    private(set) var addedListeners: [Listener] = []
    private(set) var addedKinds: [Set<EventKind>?] = []
    private(set) var removedListeners: [Listener] = []
    private(set) var askedEvents: [Event] = []
    private(set) var requestedTimeouts: [Duration] = []

    var askResponse: Event = .workspacesFetched(
        WorkspacesFetchedEvent(workspaces: [])
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
