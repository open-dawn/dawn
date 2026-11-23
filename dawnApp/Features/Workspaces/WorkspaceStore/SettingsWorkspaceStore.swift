//
//  SettingsWorkspaceStore.swift
//  dawn
//
//  Created by Rafael Venetikides on 22/09/26.
//

import Foundation
import libdawn
import Observation

@Observable
@MainActor
final class SettingsWorkspaceStore: Listener {
    private let bus: any SettingsEventBus
    private var isStarted = false

    private(set) var workspaces: [Workspace] = []
    private(set) var activity: WorkspaceActivityState = .empty
    private(set) var isLoading = false
    private(set) var error: SettingsWorkspaceStoreError?

    init(bus: any SettingsEventBus) {
        self.bus = bus
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true

        bus.addListener(
            self,
            kinds: [.availableWorkspaces]
        )
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        bus.removeListener(self)
    }

    func dismissError() {
        error = nil
    }

    func handle(_ event: Event, reply _: (@Sendable (Event) -> Void)?) {
        guard case let .availableWorkspaces(payload) = event else {
            return
        }

        workspaces = payload.workspaces
        activity = payload.activity
        error = nil
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await bus.ask(
                .getWorkspaces(GetWorkspacesEvent()),
                timeout: .seconds(5)
            )

            switch response {
            case let .workspacesFetched(payload):
                workspaces = payload.workspaces
                activity = payload.activity
                error = nil

            case let .availableWorkspaces(payload):
                workspaces = payload.workspaces
                activity = payload.activity
                error = nil

            default:
                error = .unexpectedResponse(response.kind)
            }
        } catch {
            self.error = SettingsWorkspaceStoreError(error)
        }
    }

    private func askForAcknowledgement(_ event: Event, expectedWorkspaceID: UUID? = nil)
        async throws(SettingsWorkspaceStoreError) -> UUID
    {
        do {
            let response = try await bus.ask(event, timeout: .seconds(5))

            guard case let .workspaceMutationAcknowledged(acknowledgement) = response else {
                throw SettingsWorkspaceStoreError.unexpectedResponse(response.kind)
            }

            switch acknowledgement {
            case let .success(workspaceID):
                if let expectedWorkspaceID, workspaceID != expectedWorkspaceID {
                    throw
                        SettingsWorkspaceStoreError
                        .workspaceIdentifierMismatch(
                            expected: expectedWorkspaceID,
                            received: workspaceID
                        )
                }

                error = nil
                return workspaceID
            case let .failure(failure):
                throw SettingsWorkspaceStoreError.mutationRejected(failure)
            }
        } catch {
            let storeError = SettingsWorkspaceStoreError(error)
            self.error = storeError
            throw storeError
        }
    }

    @discardableResult
    func createWorkspace(
        name: String,
        symbol: String,
        applications: [WorkspaceApplication],
        transition: WorkspaceTransition = .default
    ) async throws(SettingsWorkspaceStoreError) -> UUID {
        try await askForAcknowledgement(
            .createWorkspace(
                CreateWorkspaceEvent(
                    name: name,
                    symbol: symbol,
                    applications: applications,
                    transition: transition
                )
            )
        )
    }

    func updateWorkspace(_ workspace: Workspace) async throws(SettingsWorkspaceStoreError) {
        _ = try await askForAcknowledgement(
            .updateWorkspace(UpdateWorkspaceEvent(workspace: workspace)),
            expectedWorkspaceID: workspace.id
        )
    }

    func deleteWorkspace(id: UUID) async throws(SettingsWorkspaceStoreError) {
        _ = try await askForAcknowledgement(
            .deleteWorkspace(
                DeleteWorkspaceEvent(
                    workspaceID: id
                )
            ),
            expectedWorkspaceID: id
        )
    }

    func archiveWorkspace(id: UUID) async throws(SettingsWorkspaceStoreError) {
        _ = try await askForAcknowledgement(
            .archiveWorkspace(ArchiveWorkspaceEvent(workspaceID: id)),
            expectedWorkspaceID: id
        )
    }

    func unarchiveWorkspace(id: UUID) async throws(SettingsWorkspaceStoreError) {
        _ = try await askForAcknowledgement(
            .unarchiveWorkspace(UnarchiveWorkspaceEvent(workspaceID: id)),
            expectedWorkspaceID: id
        )
    }

    func switchWorkspace(id: UUID) async throws(SettingsWorkspaceStoreError) {
        _ = try await askForAcknowledgement(
            .switchWorkspace(SwitchWorkspaceEvent(workspaceID: id)),
            expectedWorkspaceID: id
        )
    }

    func stopWorkspace(id: UUID) async throws(SettingsWorkspaceStoreError) {
        _ = try await askForAcknowledgement(
            .stopWorkspace(StopWorkspaceEvent(workspaceID: id)),
            expectedWorkspaceID: id
        )
    }
}
