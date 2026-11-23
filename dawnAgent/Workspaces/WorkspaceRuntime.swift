//
//  WorkspaceRuntime.swift
//  dawn
//
//  Created by Rafael Venetikides on 06/10/26.
//

import Foundation
import Observation
import libdawn

@MainActor
protocol WorkspaceCoordinating: WorkspaceProviding {
    var workspaces: [Workspace] { get }
    var workspaceActivity: WorkspaceActivityState { get }
    var activeWorkspaceID: UUID? { get }
    var activeSince: Date? { get }

    func refresh() async
    func activateWorkspace(id: UUID) async throws
    func stopActiveWorkspace() async throws
}

@Observable
@MainActor
final class WorkspaceRuntime: WorkspaceCoordinating {
    private let workspaceCatalog: any WorkspaceManaging
    private let workspaceSwitching: any WorkspaceSwitching
    private let clock: any WorkspaceClock
    private let snapshotPublisher: (any WorkspaceSnapshotPublishing)?

    @ObservationIgnored
    private var refreshGeneration: UInt = 0

    private(set) var workspaces: [Workspace] = []
    private(set) var workspaceActivity: WorkspaceActivityState = .empty

    var activeWorkspaceID: UUID? {
        workspaceActivity.activeWorkspaceID
    }

    var activeSince: Date? {
        workspaceActivity.activeSince
    }

    init(
        workspaceCatalog: any WorkspaceManaging,
        workspaceSwitching: any WorkspaceSwitching = DefaultWorkspaceSwitching(),
        clock: any WorkspaceClock = SystemWorkspaceClock(),
        snapshotPublisher: (any WorkspaceSnapshotPublishing)? = nil
    ) {
        self.workspaceCatalog = workspaceCatalog
        self.workspaceSwitching = workspaceSwitching
        self.clock = clock
        self.snapshotPublisher = snapshotPublisher
    }

    func refresh() async {
        refreshGeneration &+= 1
        let generation = refreshGeneration

        let snapshot = await workspaceCatalog.getWorkspaceSnapshot()

        guard generation == refreshGeneration else {
            return
        }

        workspaces = snapshot.workspaces
        workspaceActivity = snapshot.activity
    }

    func getAvailableWorkspaces() async -> [Workspace] {
        await refresh()
        return workspaces
    }

    func getWorkspace(id: UUID) async -> Workspace? {
        await workspaceCatalog.getWorkspace(id: id)
    }

    func createWorkspace(
        name: String,
        symbol: String,
        applications: [WorkspaceApplication],
        transition: WorkspaceTransition = .default
    ) async throws -> Workspace {
        let workspace = try await workspaceCatalog.createWorkspace(
            name: name,
            symbol: symbol,
            applications: applications,
            transition: transition
        )

        await refresh()
        return workspace
    }

    func updateWorkspace(_ workspace: Workspace) async throws {
        try await workspaceCatalog.updateWorkspace(workspace)
        await refresh()
    }

    func deleteWorkspace(id: UUID) async throws {
        try await workspaceCatalog.deleteWorkspace(id: id)
        await refresh()
    }

    func archiveWorkspace(id: UUID) async throws {
        try await workspaceCatalog.archiveWorkspace(id: id)
        await refresh()
    }

    func unarchiveWorkspace(id: UUID) async throws {
        try await workspaceCatalog.unarchiveWorkspace(id: id)
        await refresh()
    }

    func activateWorkspace(id: UUID) async throws {
        guard let workspace = await workspaceCatalog.getWorkspace(id: id) else {
            throw SettingsStoreError.workspaceNotFound(id)
        }

        guard !workspace.isArchived else {
            throw SettingsStoreError.workspaceArchived(id)
        }

        try await workspaceSwitching.switchToWorkspace(to: workspace)

        workspaceActivity = try await workspaceCatalog.recordWorkspaceActivation(
            workspaceID: workspace.id,
            at: clock.now
        )
        publishSnapshot()
    }

    func stopActiveWorkspace() async throws {
        workspaceActivity = try await workspaceCatalog.stopActiveWorkspace(at: clock.now)
        publishSnapshot()
    }

    func lastActiveAt(for workspaceID: UUID) -> Date? {
        workspaceActivity.lastActiveAt(for: workspaceID)
    }

    private func publishSnapshot() {
        snapshotPublisher?.publishAvailableWorkspaces(
            workspaces,
            activity: workspaceActivity
        )
    }
}
