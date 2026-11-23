import Foundation
import Testing
import libdawn

@testable import dawnAgent

@MainActor
@Suite("WindowManagerListener")
struct WindowManagerListenerTests {
    @Test("bus uses WindowManagerListener as EventHandler")
    func busUseListernerAsHandler() throws {
        let events: [(event: Event, afterResult: Bool)] = [
            (event: Event.debugPing(DebugPingEvent()), afterResult: false),
            (event: Event.initialized(InitializedEvent()), afterResult: true),
            (event: Event.getWorkspaces(GetWorkspacesEvent()), afterResult: true),
            (
                event: Event.createWorkspace(
                    CreateWorkspaceEvent(name: "Placeholder", symbol: "book", applications: [])
                ), afterResult: true
            ),
            (
                event: Event.updateWorkspace(
                    UpdateWorkspaceEvent(workspace: Workspace(name: "Placeholder", symbol: "book"))
                ), afterResult: true
            ),
            (event: Event.deleteWorkspace(DeleteWorkspaceEvent(workspaceID: UUID())), afterResult: true),
            (event: Event.archiveWorkspace(ArchiveWorkspaceEvent(workspaceID: UUID())), afterResult: true),
            (event: Event.unarchiveWorkspace(UnarchiveWorkspaceEvent(workspaceID: UUID())), afterResult: true),
            (event: Event.switchWorkspace(SwitchWorkspaceEvent(workspaceID: UUID())), afterResult: true),
            (event: Event.stopWorkspace(StopWorkspaceEvent(workspaceID: UUID())), afterResult: true),
        ]

        let mockBus = EventBus()

        for event in events {
            try #require(mockBus.hasListeners(for: event.event) == false)
        }

        let mockWorkspaceCatalog = FakeWorkspaceCatalog()
        let runtime = WorkspaceRuntime(workspaceCatalog: mockWorkspaceCatalog)
        let listener = WindowManagerListener(bus: mockBus, workspace: runtime, lifecycle: AgentLifecycleState())
        for event in events {
            #expect(mockBus.hasListeners(for: event.event) == event.afterResult)
        }

        _ = listener  // Fix warning of not used variable
    }

    @Test("handle get workspaces event")
    func handle_GetWorkspacesEvent() async throws {
        let mockBus = EventBus()
        let mockWorkspaceCatalog = FakeWorkspaceCatalog()
        let runtime = WorkspaceRuntime(workspaceCatalog: mockWorkspaceCatalog)
        let listener = WindowManagerListener(bus: mockBus, workspace: runtime, lifecycle: AgentLifecycleState())

        let event = Event.getWorkspaces(GetWorkspacesEvent())
        let eventResponse = try await mockBus.ask(event)

        guard case .workspacesFetched(let payload) = eventResponse else {
            Issue.record("Expected .workspacesFetched \(eventResponse)")
            return
        }
        #expect(payload.workspaces == mockWorkspaceCatalog.workspaces)

        _ = listener  // Fix warning of not used variable
    }

    @Test("getAllWorkspaces return the same of WorkspaceCatalog")
    func getAllWorkspacesRespectWorkspaceCatalogReturns() async {
        let mockWorkspaceCatalog = FakeWorkspaceCatalog()
        mockWorkspaceCatalog.workspaces = createMockWorkspace(3)
        let runtime = WorkspaceRuntime(workspaceCatalog: mockWorkspaceCatalog)

        let mockBus = EventBus()
        let listener = WindowManagerListener(bus: mockBus, workspace: runtime, lifecycle: AgentLifecycleState())

        #expect(await listener.getAllWorkspaces() == mockWorkspaceCatalog.workspaces)
    }

    @Test("Create routes payload and replies with created workspace ID")
    func createRoutesPayloadAndRepliesWithSuccess() async throws {
        let application = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari"
        )
        let transition = WorkspaceTransition(
            activationPolicy: .merge
        )

        let payload = CreateWorkspaceEvent(
            name: "Work",
            symbol: "briefcase",
            applications: [application],
            transition: transition
        )

        let createdWorkspace = Workspace(
            name: payload.name,
            symbol: payload.symbol,
            applications: payload.applications,
            transition: payload.transition
        )

        let workspaceCatalog = FakeWorkspaceCatalog()
        workspaceCatalog.createResult = createdWorkspace

        let runtime = WorkspaceRuntime(workspaceCatalog: workspaceCatalog)

        let bus = EventBus()
        let listener = WindowManagerListener(
            bus: bus,
            workspace: runtime,
            lifecycle: AgentLifecycleState()
        )

        let response = try await bus.ask(.createWorkspace(payload))

        #expect(workspaceCatalog.createPayloads == [payload])
        #expect(
            response
                == .workspaceMutationAcknowledged(
                    .success(workspaceID: createdWorkspace.id)
                )
        )

        _ = listener
    }

    @Test("Create replies with validation failure")
    func createRepliesWithValidationFailure() async throws {
        let payload = CreateWorkspaceEvent(
            name: "",
            symbol: "briefcase",
            applications: []
        )

        let workspaceCatalog = FakeWorkspaceCatalog()
        workspaceCatalog.createError = SettingsStoreError.emptyWorkspaceName

        let runtime = WorkspaceRuntime(workspaceCatalog: workspaceCatalog)

        let bus = EventBus()
        let listener = WindowManagerListener(
            bus: bus,
            workspace: runtime,
            lifecycle: AgentLifecycleState()
        )

        let response = try await bus.ask(.createWorkspace(payload))

        #expect(workspaceCatalog.createPayloads == [payload])
        #expect(
            response
                == .workspaceMutationAcknowledged(
                    .failure(failure: .emptyWorkspaceName)
                )
        )
        #expect(workspaceCatalog.workspaces.isEmpty)

        _ = listener
    }

    @Test("Published create command does not mutate workspaces")
    func publishedCreateDoesNotMutateWorkspaces() {
        let payload = CreateWorkspaceEvent(
            name: "Work",
            symbol: "briefcase",
            applications: []
        )

        let workspaceCatalog = FakeWorkspaceCatalog()

        let runtime = WorkspaceRuntime(workspaceCatalog: workspaceCatalog)

        let bus = EventBus()
        let listener = WindowManagerListener(
            bus: bus,
            workspace: runtime,
            lifecycle: AgentLifecycleState()
        )

        listener.handle(.createWorkspace(payload), reply: nil)

        #expect(workspaceCatalog.createPayloads.isEmpty)
        #expect(workspaceCatalog.workspaces.isEmpty)
    }

    @Test("Update routes workspace and replies with its ID")
    func updateRoutesWorkspaceAndRepliesWithSuccess() async throws {
        var workspace = Workspace(
            name: "Work",
            symbol: "briefcase",
            applications: []
        )

        let workspaceCatalog = FakeWorkspaceCatalog()
        workspaceCatalog.workspaces = [workspace]

        workspace.name = "Updated Work"

        let runtime = WorkspaceRuntime(workspaceCatalog: workspaceCatalog)

        let payload = UpdateWorkspaceEvent(workspace: workspace)
        let bus = EventBus()
        let listener = WindowManagerListener(
            bus: bus,
            workspace: runtime,
            lifecycle: AgentLifecycleState()
        )

        let response = try await bus.ask(.updateWorkspace(payload))

        #expect(workspaceCatalog.updatedWorkspaces == [workspace])
        #expect(workspaceCatalog.workspaces == [workspace])
        #expect(
            response
                == .workspaceMutationAcknowledged(
                    .success(workspaceID: workspace.id)
                )
        )

        _ = listener
    }

    @Test("Update replies with workspace-not-found failure")
    func updateRepliesWithMissingWorkspaceFailure() async throws {
        let workspace = Workspace(
            name: "Missing",
            symbol: "questionmark",
            applications: []
        )

        let workspaceCatalog = FakeWorkspaceCatalog()
        workspaceCatalog.updateError = SettingsStoreError.workspaceNotFound(
            workspace.id
        )

        let runtime = WorkspaceRuntime(workspaceCatalog: workspaceCatalog)

        let bus = EventBus()
        let listener = WindowManagerListener(
            bus: bus,
            workspace: runtime,
            lifecycle: AgentLifecycleState()
        )

        let response = try await bus.ask(
            .updateWorkspace(
                UpdateWorkspaceEvent(workspace: workspace)
            )
        )

        #expect(workspaceCatalog.updatedWorkspaces == [workspace])
        #expect(
            response
                == .workspaceMutationAcknowledged(
                    .failure(
                        failure: .workspaceNotFound(workspace.id)
                    )
                )
        )

        _ = listener
    }

    @Test("Delete replies with workspace-not-found failure")
    func deleteRepliesWithMissingWorkspaceFailure() async throws {
        let missingID = UUID()

        let workspaceCatalog = FakeWorkspaceCatalog()
        workspaceCatalog.deleteError = SettingsStoreError.workspaceNotFound(
            missingID
        )

        let runtime = WorkspaceRuntime(workspaceCatalog: workspaceCatalog)

        let bus = EventBus()
        let listener = WindowManagerListener(
            bus: bus,
            workspace: runtime,
            lifecycle: AgentLifecycleState()
        )

        let response = try await bus.ask(
            .deleteWorkspace(
                DeleteWorkspaceEvent(workspaceID: missingID)
            )
        )

        #expect(workspaceCatalog.deletedWorkspaceIDs == [missingID])
        #expect(
            response
                == .workspaceMutationAcknowledged(
                    .failure(
                        failure: .workspaceNotFound(missingID)
                    )
                )
        )

        _ = listener
    }

    @Test("Delete routes ID and replies with deleted workspace ID")
    func deleteRoutesIDAndRepliesWithSuccess() async throws {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase",
            applications: []
        )

        let workspaceCatalog = FakeWorkspaceCatalog()
        workspaceCatalog.workspaces = [workspace]

        let runtime = WorkspaceRuntime(workspaceCatalog: workspaceCatalog)

        let payload = DeleteWorkspaceEvent(workspaceID: workspace.id)
        let bus = EventBus()
        let listener = WindowManagerListener(
            bus: bus,
            workspace: runtime,
            lifecycle: AgentLifecycleState()
        )

        let response = try await bus.ask(.deleteWorkspace(payload))

        #expect(workspaceCatalog.deletedWorkspaceIDs == [workspace.id])
        #expect(workspaceCatalog.workspaces.isEmpty)
        #expect(
            response
                == .workspaceMutationAcknowledged(
                    .success(workspaceID: workspace.id)
                )
        )

        _ = listener
    }

    @Test("Switch workspace activates workspace and replies with its ID")
    func switchWorkspaceActivatesWorkspaceAndRepliesWithSuccess() async throws {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase",
            applications: []
        )

        let workspaceCatalog = FakeWorkspaceCatalog()
        workspaceCatalog.workspaces = [workspace]

        let switcher = WorkspaceSwitchingSpy()

        let runtime = WorkspaceRuntime(workspaceCatalog: workspaceCatalog, workspaceSwitching: switcher)

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

        #expect(switcher.switchedWorkspaces == [workspace])
        #expect(runtime.activeWorkspaceID == workspace.id)
        #expect(
            response
                == .workspaceMutationAcknowledged(
                    .success(workspaceID: workspace.id)
                )
        )

        _ = listener
    }

    @Test("Switch workspace replies with workspace-not-found")
    func switchWorkspaceRepliesWithMissingWorkspaceFailure() async throws {
        let missingID = UUID()

        let workspaceCatalog = FakeWorkspaceCatalog()
        let switcher = WorkspaceSwitchingSpy()

        let runtime = WorkspaceRuntime(workspaceCatalog: workspaceCatalog, workspaceSwitching: switcher)

        let bus = EventBus()
        let listener = WindowManagerListener(
            bus: bus,
            workspace: runtime,
            lifecycle: AgentLifecycleState()
        )

        let response = try await bus.ask(
            .switchWorkspace(
                SwitchWorkspaceEvent(workspaceID: missingID)
            )
        )

        #expect(switcher.switchedWorkspaces.isEmpty)
        #expect(runtime.activeWorkspaceID == nil)
        #expect(
            response
                == .workspaceMutationAcknowledged(
                    .failure(
                        failure: .workspaceNotFound(missingID)
                    )
                )
        )

        _ = listener
    }

    @Test("Stop workspace clears active workspace and replies with its ID")
    func stopWorkspaceClearsActiveWorkspaceAndRepliesWithSuccess() async throws {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )

        let workspaceCatalog = FakeWorkspaceCatalog()
        workspaceCatalog.workspaces = [workspace]
        workspaceCatalog.workspaceActivity.activate(
            workspaceID: workspace.id,
            at: Date(timeIntervalSince1970: 100)
        )

        let runtime = WorkspaceRuntime(workspaceCatalog: workspaceCatalog)
        await runtime.refresh()

        let bus = EventBus()
        let listener = WindowManagerListener(bus: bus, workspace: runtime, lifecycle: AgentLifecycleState())

        let response = try await bus.ask(
            .stopWorkspace(StopWorkspaceEvent(workspaceID: workspace.id))
        )

        #expect(runtime.activeWorkspaceID == nil)
        #expect(workspaceCatalog.workspaceActivity.activeWorkspaceID == nil)
        #expect(
            response
                == .workspaceMutationAcknowledged(
                    .success(workspaceID: workspace.id)
                )
        )

        _ = listener
    }

    @Test("Stop workspace rejects an ID that is not active")
    func stopWorkspaceRejectsInactiveWorkspace() async throws {
        let activeWorkspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )
        let inactiveWorkspace = Workspace(
            name: "Personal",
            symbol: "person"
        )

        let workspaceCatalog = FakeWorkspaceCatalog()
        workspaceCatalog.workspaces = [activeWorkspace, inactiveWorkspace]
        workspaceCatalog.workspaceActivity.activate(
            workspaceID: activeWorkspace.id,
            at: Date(timeIntervalSince1970: 100)
        )

        let runtime = WorkspaceRuntime(workspaceCatalog: workspaceCatalog)
        await runtime.refresh()

        let bus = EventBus()
        let listener = WindowManagerListener(bus: bus, workspace: runtime, lifecycle: AgentLifecycleState())

        let response = try await bus.ask(
            .stopWorkspace(StopWorkspaceEvent(workspaceID: inactiveWorkspace.id))
        )

        #expect(runtime.activeWorkspaceID == activeWorkspace.id)
        #expect(workspaceCatalog.workspaceActivity.activeWorkspaceID == activeWorkspace.id)
        #expect(
            response
                == .workspaceMutationAcknowledged(
                    .failure(failure: .workspaceNotActive(inactiveWorkspace.id))
                )
        )

        _ = listener
    }

    @Test("Archive routes ID and replies with success")
    func archiveRoutesIDAndRepliesWithSuccess() async throws {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase",
            applications: []
        )

        let workspaceCatalog = FakeWorkspaceCatalog()
        workspaceCatalog.workspaces = [workspace]

        let runtime = WorkspaceRuntime(workspaceCatalog: workspaceCatalog)
        let bus = EventBus()
        let listener = WindowManagerListener(
            bus: bus,
            workspace: runtime,
            lifecycle: AgentLifecycleState()
        )

        let response = try await bus.ask(
            .archiveWorkspace(ArchiveWorkspaceEvent(workspaceID: workspace.id))
        )

        #expect(workspaceCatalog.archivedWorkspaceIDs == [workspace.id])
        #expect(runtime.workspaces.map(\.isArchived) == [true])
        #expect(
            response
                == .workspaceMutationAcknowledged(
                    .success(workspaceID: workspace.id)
                )
        )

        _ = listener
    }

    @Test("Archive replies with workspace-not-found failure")
    func archiveRepliesWithMissingWorkspaceFailure() async throws {
        let missingID = UUID()

        let workspaceCatalog = FakeWorkspaceCatalog()
        workspaceCatalog.archiveError = SettingsStoreError.workspaceNotFound(missingID)

        let runtime = WorkspaceRuntime(workspaceCatalog: workspaceCatalog)
        let bus = EventBus()
        let listener = WindowManagerListener(
            bus: bus,
            workspace: runtime,
            lifecycle: AgentLifecycleState()
        )

        let response = try await bus.ask(
            .archiveWorkspace(ArchiveWorkspaceEvent(workspaceID: missingID))
        )

        #expect(workspaceCatalog.archivedWorkspaceIDs == [missingID])
        #expect(
            response
                == .workspaceMutationAcknowledged(
                    .failure(failure: .workspaceNotFound(missingID))
                )
        )

        _ = listener
    }

    @Test("Unarchive routes ID and replies with success")
    func unarchiveRoutesIDAndRepliesWithSuccess() async throws {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase",
            isArchived: true
        )

        let workspaceCatalog = FakeWorkspaceCatalog()
        workspaceCatalog.workspaces = [workspace]

        let runtime = WorkspaceRuntime(workspaceCatalog: workspaceCatalog)
        let bus = EventBus()
        let listener = WindowManagerListener(
            bus: bus,
            workspace: runtime,
            lifecycle: AgentLifecycleState()
        )

        let response = try await bus.ask(
            .unarchiveWorkspace(UnarchiveWorkspaceEvent(workspaceID: workspace.id))
        )

        #expect(workspaceCatalog.unarchivedWorkspaceIDs == [workspace.id])
        #expect(runtime.workspaces.map(\.id) == [workspace.id])
        #expect(runtime.workspaces.allSatisfy { !$0.isArchived })
        #expect(
            response
                == .workspaceMutationAcknowledged(
                    .success(workspaceID: workspace.id)
                )
        )

        _ = listener
    }

    @Test("Switch workspace replies with workspace-archived failure")
    func switchWorkspaceRepliesWithArchivedWorkspaceFailure() async throws {
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

        let bus = EventBus()
        let listener = WindowManagerListener(
            bus: bus,
            workspace: runtime,
            lifecycle: AgentLifecycleState()
        )

        let response = try await bus.ask(
            .switchWorkspace(SwitchWorkspaceEvent(workspaceID: workspace.id))
        )

        #expect(switcher.switchedWorkspaces.isEmpty)
        #expect(runtime.activeWorkspaceID == nil)
        #expect(
            response
                == .workspaceMutationAcknowledged(
                    .failure(failure: .workspaceArchived(workspace.id))
                )
        )

        _ = listener
    }

    @Test("Workspace mutation is rejected while preparing for update")
    func mutationIsRejectedWhilePreparing() async throws {
        let workspaceCatalog = FakeWorkspaceCatalog()
        let runtime = WorkspaceRuntime(
            workspaceCatalog: workspaceCatalog
        )

        let lifecycle = AgentLifecycleState()
        lifecycle.beginUpdatePreparation()

        let bus = EventBus()
        let listener = WindowManagerListener(
            bus: bus,
            workspace: runtime,
            lifecycle: lifecycle
        )

        let response = try await bus.ask(
            .createWorkspace(
                CreateWorkspaceEvent(
                    name: "Work",
                    symbol: "briefcase",
                    applications: []
                )
            )
        )

        #expect(
            response
                == .workspaceMutationAcknowledged(
                    .failure(failure: .updateInProgress)
                )
        )
        #expect(workspaceCatalog.createPayloads.isEmpty)

        _ = listener
    }

    @Test("Workspace reads remain available while preparing for update")
    func readsRemainAvailableWhilePreparing() async throws {
        let workspaceCatalog = FakeWorkspaceCatalog()
        let runtime = WorkspaceRuntime(
            workspaceCatalog: workspaceCatalog
        )

        let lifecycle = AgentLifecycleState()
        lifecycle.beginUpdatePreparation()

        let bus = EventBus()
        let listener = WindowManagerListener(
            bus: bus,
            workspace: runtime,
            lifecycle: lifecycle
        )

        let response = try await bus.ask(
            .getWorkspaces(GetWorkspacesEvent())
        )

        #expect(
            response
                == .workspacesFetched(
                    WorkspacesFetchedEvent(workspaces: [])
                )
        )

        _ = listener
    }

    @Test("Stop workspace is rejected while preparing for update")
    func stopWorkspaceIsRejectedWhilePreparing() async throws {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )

        let workspaceCatalog = FakeWorkspaceCatalog()
        workspaceCatalog.workspaces = [workspace]
        workspaceCatalog.workspaceActivity.activate(
            workspaceID: workspace.id,
            at: Date(timeIntervalSince1970: 100)
        )

        let runtime = WorkspaceRuntime(
            workspaceCatalog: workspaceCatalog
        )

        await runtime.refresh()

        let lifecycle = AgentLifecycleState()
        lifecycle.beginUpdatePreparation()

        let bus = EventBus()
        let listener = WindowManagerListener(
            bus: bus,
            workspace: runtime,
            lifecycle: lifecycle
        )

        let response = try await bus.ask(
            .stopWorkspace(
                StopWorkspaceEvent(workspaceID: workspace.id)
            )
        )

        #expect(
            response == .workspaceMutationAcknowledged(
                .failure(failure: .updateInProgress)
            )
        )

        // The stop operation must not reach WorkspaceRuntime.
        #expect(runtime.activeWorkspaceID == workspace.id)
        #expect(
            workspaceCatalog.workspaceActivity.activeWorkspaceID
                == workspace.id
        )

        _ = listener
    }

    private func createMockWorkspace(_ count: Int) -> [Workspace] {
        var res: [Workspace] = []
        for index in 1...count {
            res.append(Workspace(name: "placeholder \(index)", symbol: "", applications: []))
        }
        return res
    }
}

@MainActor
final class FakeWorkspaceCatalog: WorkspaceManaging {
    var workspaces: [Workspace] = []
    var workspaceActivity: WorkspaceActivityState = .empty

    private(set) var createPayloads: [CreateWorkspaceEvent] = []
    var createResult: Workspace?
    var createError: Error?

    private(set) var updatedWorkspaces: [Workspace] = []
    var updateError: Error?

    private(set) var deletedWorkspaceIDs: [UUID] = []
    var deleteError: Error?

    private(set) var archivedWorkspaceIDs: [UUID] = []
    var archiveError: Error?

    private(set) var unarchivedWorkspaceIDs: [UUID] = []
    var unarchiveError: Error?

    func getAvailableWorkspaces() async -> [Workspace] {
        workspaces
    }

    func getWorkspaceActivity() async -> WorkspaceActivityState {
        workspaceActivity
    }

    func createWorkspace(
        name: String,
        symbol: String,
        applications: [WorkspaceApplication],
        transition: WorkspaceTransition
    ) async throws -> Workspace {
        createPayloads.append(
            CreateWorkspaceEvent(
                name: name,
                symbol: symbol,
                applications: applications,
                transition: transition
            )
        )

        if let createError {
            throw createError
        }

        let workspace =
            createResult
            ?? Workspace(
                name: name,
                symbol: symbol,
                applications: applications,
                transition: transition
            )

        workspaces.append(workspace)
        return workspace
    }

    func updateWorkspace(_ workspace: Workspace) async throws {
        updatedWorkspaces.append(workspace)

        if let updateError {
            throw updateError
        }

        guard let index = workspaces.firstIndex(where: { $0.id == workspace.id }) else {
            return
        }

        workspaces[index] = workspace
    }

    func deleteWorkspace(id: UUID) async throws {
        deletedWorkspaceIDs.append(id)

        if let deleteError {
            throw deleteError
        }

        workspaceActivity.removeWorkspace(id: id)
        workspaces.removeAll { $0.id == id }
    }

    func archiveWorkspace(id: UUID) async throws {
        archivedWorkspaceIDs.append(id)

        if let archiveError {
            throw archiveError
        }

        guard let index = workspaces.firstIndex(where: { $0.id == id }) else {
            throw SettingsStoreError.workspaceNotFound(id)
        }

        workspaces[index].isArchived = true
        workspaceActivity.clearActiveSession(for: id)
    }

    func unarchiveWorkspace(id: UUID) async throws {
        unarchivedWorkspaceIDs.append(id)

        if let unarchiveError {
            throw unarchiveError
        }

        guard let index = workspaces.firstIndex(where: { $0.id == id }) else {
            throw SettingsStoreError.workspaceNotFound(id)
        }

        workspaces[index].isArchived = false
    }

    func getWorkspace(id: UUID) async -> Workspace? {
        workspaces.first { $0.id == id }
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
        WorkspaceSnapshot(
            workspaces: workspaces,
            activity: workspaceActivity
        )
    }
}

final class WorkspaceSwitchingSpy: WorkspaceSwitching {
    var switchedWorkspaces: [Workspace] = []
    var error: (any Error)?

    func switchToWorkspace(to workspace: Workspace) async throws {
        if let error {
            throw error
        }

        switchedWorkspaces.append(workspace)
    }
}
