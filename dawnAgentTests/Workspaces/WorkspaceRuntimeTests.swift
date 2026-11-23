//
//  WorkspaceRuntimeTests.swift
//  dawn
//
//  Created by Rafael Venetikides on 06/10/26.
//

import Foundation
import Testing
import libdawn

@testable import dawnAgent

@MainActor
@Suite("WorkspaceRuntime")
struct WorkspaceRuntimeTests {
    @Test("Refresh exposes the authoritative workspace snapshot")
    func refreshLoadsWorkspaces() async throws {
        let expectedWorkspaces = [
            Workspace(
                name: "Work",
                symbol: "briefcase"
            ),
            Workspace(
                name: "Personal",
                symbol: "person"
            ),
        ]

        let workspaceCatalog = FakeWorkspaceCatalog()
        workspaceCatalog.workspaces = expectedWorkspaces

        let runtime = WorkspaceRuntime(
            workspaceCatalog: workspaceCatalog,
            workspaceSwitching: WorkspaceSwitchingSpy()
        )

        await runtime.refresh()

        #expect(runtime.workspaces == expectedWorkspaces)
    }

    @Test("Creating a workspace refreshes observable workspaces")
    func createRefreshesWorkspaces() async throws {
        let workspaceCatalog = FakeWorkspaceCatalog()
        let runtime = WorkspaceRuntime(
            workspaceCatalog: workspaceCatalog,
            workspaceSwitching: WorkspaceSwitchingSpy()
        )

        let createdWorkspace = try await runtime.createWorkspace(
            name: "Work",
            symbol: "briefcase",
            applications: []
        )

        #expect(runtime.workspaces == [createdWorkspace])
        #expect(workspaceCatalog.workspaces == [createdWorkspace])
    }

    @Test("Activating a workspace delegates to the switcher")
    func activateDelegatesToSwitcher() async throws {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )

        let workspaceCatalog = FakeWorkspaceCatalog()
        workspaceCatalog.workspaces = [workspace]

        let switcher = WorkspaceSwitchingSpy()

        let runtime = WorkspaceRuntime(
            workspaceCatalog: workspaceCatalog,
            workspaceSwitching: switcher
        )

        try await runtime.activateWorkspace(id: workspace.id)

        #expect(switcher.switchedWorkspaces == [workspace])
        #expect(runtime.activeWorkspaceID == workspace.id)
    }

    @Test("Activating a missing workspace fails")
    func activatingMissingWorkspaceFails() async {
        let missingID = UUID()

        let runtime = WorkspaceRuntime(
            workspaceCatalog: FakeWorkspaceCatalog(),
            workspaceSwitching: WorkspaceSwitchingSpy()
        )

        await #expect(
            throws: SettingsStoreError.workspaceNotFound(missingID)
        ) {
            try await runtime.activateWorkspace(id: missingID)
        }

        #expect(runtime.activeWorkspaceID == nil)
    }

    @Test("Deleting the active workspace clears its active state")
    func deletingActiveWorkspaceClearsSelection() async throws {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )

        let workspaceCatalog = FakeWorkspaceCatalog()
        workspaceCatalog.workspaces = [workspace]

        let runtime = WorkspaceRuntime(
            workspaceCatalog: workspaceCatalog,
            workspaceSwitching: WorkspaceSwitchingSpy()
        )

        try await runtime.activateWorkspace(id: workspace.id)
        try await runtime.deleteWorkspace(id: workspace.id)

        #expect(runtime.workspaces.isEmpty)
        #expect(runtime.activeWorkspaceID == nil)
    }

    @Test("Activating an archived workspace fails without switching")
    func activatingArchivedWorkspaceFails() async {
        let workspace = Workspace(
            name: "Old",
            symbol: "archivebox",
            isArchived: true
        )

        let workspaceCatalog = FakeWorkspaceCatalog()
        workspaceCatalog.workspaces = [workspace]
        let switcher = WorkspaceSwitchingSpy()

        let runtime = WorkspaceRuntime(
            workspaceCatalog: workspaceCatalog,
            workspaceSwitching: switcher
        )

        await #expect(
            throws: SettingsStoreError.workspaceArchived(workspace.id)
        ) {
            try await runtime.activateWorkspace(id: workspace.id)
        }

        #expect(switcher.switchedWorkspaces.isEmpty)
        #expect(runtime.activeWorkspaceID == nil)
    }

    @Test("Archiving the requested workspace clears it on refresh")
    func archivingRequestedWorkspaceClearsSelection() async throws {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )

        let workspaceCatalog = FakeWorkspaceCatalog()
        workspaceCatalog.workspaces = [workspace]

        let runtime = WorkspaceRuntime(
            workspaceCatalog: workspaceCatalog,
            workspaceSwitching: WorkspaceSwitchingSpy()
        )

        try await runtime.activateWorkspace(id: workspace.id)
        try await runtime.archiveWorkspace(id: workspace.id)

        #expect(runtime.workspaces.map(\.isArchived) == [true])
        #expect(runtime.activeWorkspaceID == nil)
        #expect(workspaceCatalog.workspaces == [
            Workspace(
                id: workspace.id,
                name: workspace.name,
                symbol: workspace.symbol,
                isArchived: true
            )
        ])
    }

    @Test("Older refresh cannot overwrite a newer snapshot")
    func olderRefreshCannotOverwriteNewerSnapshot() async throws {
        let oldWorkspaces = [
            Workspace(
                name: "Old",
                symbol: "clock"
            )
        ]

        let newWorkspaces = [
            Workspace(
                name: "New",
                symbol: "sparkles"
            )
        ]

        let workspaceCatalog = OutOfOrderWorkspaceProvider(workspaces: oldWorkspaces)

        let runtime = WorkspaceRuntime(
            workspaceCatalog: workspaceCatalog,
            workspaceSwitching: WorkspaceSwitchingSpy()
        )

        let olderRefresh = Task { @MainActor in
            await runtime.refresh()
        }

        await workspaceCatalog.waitUntilFirstRequest()

        workspaceCatalog.workspaces = newWorkspaces
        await runtime.refresh()

        #expect(runtime.workspaces == newWorkspaces)

        workspaceCatalog.resumeFirstRequest()
        await olderRefresh.value

        #expect(runtime.workspaces == newWorkspaces)
    }

    @Test("Failed activation preserves the previously active workspace")
    func failedActivationPreservesSelection() async throws {
        let initiallyActiveWorkspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )

        let failingWorkspace = Workspace(
            name: "Personal",
            symbol: "person"
        )

        let workspaceCatalog = FakeWorkspaceCatalog()
        workspaceCatalog.workspaces = [
            initiallyActiveWorkspace,
            failingWorkspace
        ]

        let switcher = WorkspaceSwitchingSpy()

        let runtime = WorkspaceRuntime(
            workspaceCatalog: workspaceCatalog,
            workspaceSwitching: switcher
        )

        try await runtime.activateWorkspace(
            id: initiallyActiveWorkspace.id
        )

        switcher.error = WorkspaceSwitchingTestError.failed

        await #expect(throws: WorkspaceSwitchingTestError.failed) {
            try await runtime.activateWorkspace(id: failingWorkspace.id)
        }

        #expect(runtime.activeWorkspaceID == initiallyActiveWorkspace.id)

        #expect(switcher.switchedWorkspaces == [initiallyActiveWorkspace])
    }

    @Test("Switch workspace replies with unexpected failure when activation fails")
    func switchWorkspaceRepliesWithActivationFailure() async throws {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )

        let workspaceCatalog = FakeWorkspaceCatalog()
        workspaceCatalog.workspaces = [workspace]

        let switcher = WorkspaceSwitchingSpy()
        switcher.error = WorkspaceSwitchingTestError.failed

        let runtime = WorkspaceRuntime(
            workspaceCatalog: workspaceCatalog,
            workspaceSwitching: switcher
        )

        let bus = EventBus()
        let listener = WindowManagerListener(
            bus: bus,
            workspace: runtime,
            lifecycle: AgentLifecycleState()
        )

        let response = try await bus.ask(
            .switchWorkspace(
                SwitchWorkspaceEvent(workspaceID: workspace.id)
            )
        )

        #expect(
            response == .workspaceMutationAcknowledged(
                .failure(failure: .unexpected)
            )
        )
        #expect(runtime.activeWorkspaceID == nil)

        _ = listener
    }

    @Test("Activating a workspace records persisted activity")
    func activateRecordsActivity() async throws {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )

        let activatedAt = Date(timeIntervalSince1970: 100)

        let workspaceCatalog = FakeWorkspaceCatalog()
        workspaceCatalog.workspaces = [workspace]

        let switcher = WorkspaceSwitchingSpy()
        let clock = TestWorkspaceClock(
            now: activatedAt
        )

        let runtime = WorkspaceRuntime(
            workspaceCatalog: workspaceCatalog,
            workspaceSwitching: switcher,
            clock: clock
        )

        try await runtime.activateWorkspace(id: workspace.id)

        #expect(switcher.switchedWorkspaces == [workspace])
        #expect(runtime.activeWorkspaceID == workspace.id)
        #expect(runtime.activeSince == activatedAt)
        #expect(workspaceCatalog.workspaceActivity == runtime.workspaceActivity)
    }

    @Test("Refresh loads persisted workspace activity")
    func refreshLoadsActivity() async {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )

        let activeSince = Date(timeIntervalSince1970: 100)

        let workspaceCatalog = FakeWorkspaceCatalog()
        workspaceCatalog.workspaces = [workspace]
        workspaceCatalog.workspaceActivity.activate(
            workspaceID: workspace.id,
            at: activeSince
        )

        let runtime = WorkspaceRuntime(
            workspaceCatalog: workspaceCatalog,
            workspaceSwitching: WorkspaceSwitchingSpy()
        )

        await runtime.refresh()

        #expect(runtime.activeWorkspaceID == workspace.id)
        #expect(runtime.activeSince == activeSince)
    }

    @Test("Stopping clears active state using the injected clock")
    func stopClearsActiveState() async throws {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )
        let clock = TestWorkspaceClock(
            now: Date(timeIntervalSince1970: 100)
        )

        let workspaceCatalog = FakeWorkspaceCatalog()
        workspaceCatalog.workspaces = [workspace]
        let publisher = RuntimeSnapshotPublisherSpy()

        let runtime = WorkspaceRuntime(
            workspaceCatalog: workspaceCatalog,
            workspaceSwitching: WorkspaceSwitchingSpy(),
            clock: clock,
            snapshotPublisher: publisher
        )

        await runtime.refresh()
        try await runtime.activateWorkspace(id: workspace.id)

        let stoppedAt = Date(timeIntervalSince1970: 200)
        clock.now = stoppedAt

        try await runtime.stopActiveWorkspace()

        #expect(runtime.activeWorkspaceID == nil)
        #expect(runtime.activeSince == nil)
        #expect(runtime.lastActiveAt(for: workspace.id) == stoppedAt)
        #expect(publisher.workspaceSnapshots == [[workspace], [workspace]])
        #expect(
            publisher.activitySnapshots.map(\.activeWorkspaceID)
                == [workspace.id, nil]
        )
    }
}

@MainActor
private final class RuntimeSnapshotPublisherSpy: WorkspaceSnapshotPublishing {
    private(set) var workspaceSnapshots: [[Workspace]] = []
    private(set) var activitySnapshots: [WorkspaceActivityState] = []

    func publishAvailableWorkspaces(
        _ workspaces: [Workspace],
        activity: WorkspaceActivityState
    ) {
        workspaceSnapshots.append(workspaces)
        activitySnapshots.append(activity)
    }
}

@MainActor
private final class OutOfOrderWorkspaceProvider: WorkspaceManaging {
    var workspaces: [Workspace]
    var workspaceActivity: WorkspaceActivityState = .empty

    private var requestCount = 0

    private var firstRequestSnapshot: WorkspaceSnapshot?
    private var firstRequestContinuation:
    CheckedContinuation<WorkspaceSnapshot, Never>?

    private var firstRequestWaiter:
        CheckedContinuation<Void, Never>?

    init(workspaces: [Workspace]) {
        self.workspaces = workspaces
    }

    func getAvailableWorkspaces() async -> [Workspace] {
        workspaces
    }

    func waitUntilFirstRequest() async {
        guard firstRequestContinuation == nil else {
            return
        }

        await withCheckedContinuation {
            firstRequestWaiter = $0
        }
    }

    func resumeFirstRequest() {
        guard
            let snapshot = firstRequestSnapshot,
            let continuation = firstRequestContinuation
        else {
            return
        }

        firstRequestSnapshot = nil
        firstRequestContinuation = nil

        continuation.resume(returning: snapshot)
    }

    func getWorkspace(id: UUID) async -> Workspace? {
        workspaces.first { $0.id == id }
    }

    func archiveWorkspace(id: UUID) async throws {
        fatalError("Not used by this test")
    }

    func unarchiveWorkspace(id: UUID) async throws {
        fatalError("Not used by this test")
    }

    func createWorkspace(
        name: String,
        symbol: String,
        applications: [WorkspaceApplication],
        transition: WorkspaceTransition
    ) async throws -> Workspace {
        fatalError("Not used by this test")
    }

    func updateWorkspace(_ workspace: Workspace) async throws {
        fatalError("Not used by this test")
    }

    func deleteWorkspace(id: UUID) async throws {
        fatalError("Not used by this test")
    }

    func getWorkspaceActivity() async -> WorkspaceActivityState {
        workspaceActivity
    }

    func recordWorkspaceActivation(workspaceID: UUID, at date: Date) async throws -> WorkspaceActivityState {
        guard workspaces.contains(where: { $0.id == workspaceID }) else {
            throw SettingsStoreError.workspaceNotFound(workspaceID)
        }

        workspaceActivity.activate(
            workspaceID: workspaceID,
            at: date
        )

        return workspaceActivity
    }

    func stopActiveWorkspace(at date: Date) async throws -> WorkspaceActivityState {
        workspaceActivity.stop(at: date)
        return workspaceActivity
    }

    func getWorkspaceSnapshot() async -> WorkspaceSnapshot {
        requestCount += 1

        let snapshot = WorkspaceSnapshot(
            workspaces: workspaces,
            activity: workspaceActivity
        )

        guard requestCount == 1 else {
            return snapshot
        }

        firstRequestSnapshot = snapshot

        return await withCheckedContinuation { continuation in
            firstRequestContinuation = continuation

            firstRequestWaiter?.resume()
            firstRequestWaiter = nil
        }
    }
}

@MainActor
private final class TestWorkspaceClock: WorkspaceClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

private enum WorkspaceSwitchingTestError: Error, Equatable {
    case failed
}
