import Foundation
import libdawn

final class WorkspaceCatalog: WorkspaceManaging {
    private let store: SettingsStore
    private let snapshotPublisher: WorkspaceSnapshotPublishing

    init(
        store: SettingsStore,
        snapshotPublisher: WorkspaceSnapshotPublishing
    ) {
        self.store = store
        self.snapshotPublisher = snapshotPublisher
    }

    func getAvailableWorkspaces() async -> [Workspace] {
        await store.snapshot().workspaces
    }

    func getWorkspaceSnapshot() async -> WorkspaceSnapshot {
        let document = await store.snapshot()

        return WorkspaceSnapshot(
            workspaces: document.workspaces,
            activity: document.workspaceActivity
        )
    }

    func createWorkspace(
        name: String,
        symbol: String,
        applications: [WorkspaceApplication],
        transition: WorkspaceTransition = .default
    ) async throws -> Workspace {
        let workspace = try await store.createWorkspace(
            name: name,
            symbol: symbol,
            applications: applications,
            transition: transition
        )

        await publishAvailableWorkspaces()
        return workspace
    }

    func getWorkspace(id: UUID) async -> Workspace? {
        let workspaces = await store.snapshot().workspaces
        return workspaces.first(where: { $0.id == id })
    }

    func updateWorkspace(_ workspace: Workspace) async throws {
        try await store.updateWorkspace(workspace)
        await publishAvailableWorkspaces()
    }

    func deleteWorkspace(id: UUID) async throws {
        try await store.deleteWorkspace(id: id)
        await publishAvailableWorkspaces()
    }

    func archiveWorkspace(id: UUID) async throws {
        try await store.archiveWorkspace(id: id)
        await publishAvailableWorkspaces()
    }

    func unarchiveWorkspace(id: UUID) async throws {
        try await store.unarchiveWorkspace(id: id)
        await publishAvailableWorkspaces()
    }

    private func publishAvailableWorkspaces() async {
        let snapshot = await store.snapshot()
        snapshotPublisher.publishAvailableWorkspaces(
            snapshot.workspaces,
            activity: snapshot.workspaceActivity
        )
    }

    func getWorkspaceActivity() async -> WorkspaceActivityState {
        let snapshot = await store.snapshot()

        return snapshot.workspaceActivity
    }

    @discardableResult
    func recordWorkspaceActivation(workspaceID: UUID, at date: Date) async throws -> WorkspaceActivityState {
        try await store.recordWorkspaceActivation(workspaceID: workspaceID, at: date)
    }

    @discardableResult
    func stopActiveWorkspace(at date: Date) async throws -> WorkspaceActivityState {
        try await store.stopActiveWorkspace(at: date)
    }
}

@MainActor
protocol WorkspaceProviding {
    func getAvailableWorkspaces() async -> [Workspace]

    func createWorkspace(
        name: String,
        symbol: String,
        applications: [WorkspaceApplication],
        transition: WorkspaceTransition
    ) async throws -> Workspace
    func updateWorkspace(_ workspace: Workspace) async throws
    func deleteWorkspace(id: UUID) async throws

    func archiveWorkspace(id: UUID) async throws

    func unarchiveWorkspace(id: UUID) async throws

    func getWorkspace(id: UUID) async -> Workspace?
}
