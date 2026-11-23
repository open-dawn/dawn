import dawnLogging
import libdawn

@MainActor
protocol WorkspaceSwitching {
    func switchToWorkspace(to workspace: Workspace) async throws
}

@MainActor
final class DefaultWorkspaceSwitching: WorkspaceSwitching {
    private var tail: Task<Void, Never>?

    func switchToWorkspace(to workspace: Workspace) async throws {
        let previous = tail
        let transition = Task { @MainActor in
            await previous?.value
            try await WMActionIdentifier.workspaceTransition(workspace).action.execute()
        }
        tail = Task {
            _ = try? await transition.value
        }
        try await transition.value
    }
}

@MainActor
final class WindowManagerListener: Listener {
    private let workspace: any WorkspaceCoordinating
    private let lifecycle: AgentLifecycleState

    init(
        bus: EventBus,
        workspace: any WorkspaceCoordinating,
        lifecycle: AgentLifecycleState
    ) {
        self.workspace = workspace
        self.lifecycle = lifecycle

        bus.addListener(
            self,
            kinds: [
                .initialized,
                .getWorkspaces,
                .createWorkspace,
                .updateWorkspace,
                .deleteWorkspace,
                .archiveWorkspace,
                .unarchiveWorkspace,
                .switchWorkspace,
                .stopWorkspace,
            ]
        )
    }

    func handle(
        _ event: Event,
        reply: (@Sendable (Event) -> Void)?
    ) {
        guard accepts(event, reply: reply) else {
            return
        }

        if event.isWorkspaceMutation {
            handleMutationEvent(event, reply: reply)
        } else {
            handleNonMutationEvent(event, reply: reply)
        }
    }

    private func handleNonMutationEvent(
        _ event: Event,
        reply: (@Sendable (Event) -> Void)?
    ) {
        switch event {
        case .getWorkspaces:
            Task { @MainActor in
                let workspaces = await getAllWorkspaces()

                reply?(
                    .workspacesFetched(
                        WorkspacesFetchedEvent(
                            workspaces: workspaces,
                            activity: workspace.workspaceActivity
                        )
                    )
                )
            }

        case .initialized:
            #log(
                "dawnAgent initialized",
                level: .info,
                category: .appLifecycle
            )

        default:
            return
        }
    }

    private func handleMutationEvent(
        _ event: Event,
        reply: (@Sendable (Event) -> Void)?
    ) {
        switch event {
        case .createWorkspace(let payload):
            handleCreateWorkspace(payload, reply: reply)

        case .updateWorkspace(let payload):
            handleUpdateWorkspace(payload, reply: reply)

        case .deleteWorkspace(let payload):
            handleDeleteWorkspace(payload, reply: reply)

        case .archiveWorkspace(let payload):
            handleArchiveWorkspace(payload, reply: reply)

        case .unarchiveWorkspace(let payload):
            handleUnarchiveWorkspace(payload, reply: reply)

        case .switchWorkspace(let payload):
            handleSwitchWorkspace(payload, reply: reply)

        case .stopWorkspace(let payload):
            handleStopWorkspace(payload, reply: reply)

        default:
            return
        }
    }

    func getAllWorkspaces() async -> [Workspace] {
        await workspace.getAvailableWorkspaces()
    }
}

extension WindowManagerListener {

    private func handleCreateWorkspace(_ payload: CreateWorkspaceEvent, reply: (@Sendable (Event) -> Void)?) {
        guard let reply else { return }

        Task { @MainActor in
            do {
                let created = try await workspace.createWorkspace(
                    name: payload.name,
                    symbol: payload.symbol,
                    applications: payload.applications,
                    transition: payload.transition
                )

                reply(
                    .workspaceMutationAcknowledged(
                        .success(workspaceID: created.id)
                    )
                )
            } catch {
                reply(
                    .workspaceMutationAcknowledged(
                        .failure(
                            failure: mutationFailure(from: error)
                        )
                    )
                )
            }
        }
    }

    private func handleUpdateWorkspace(_ payload: UpdateWorkspaceEvent, reply: (@Sendable (Event) -> Void)?) {
        guard let reply else { return }

        Task { @MainActor in
            do {
                try await workspace.updateWorkspace(
                    payload.workspace
                )

                reply(
                    .workspaceMutationAcknowledged(
                        .success(workspaceID: payload.workspace.id)
                    )
                )
            } catch {
                reply(
                    .workspaceMutationAcknowledged(
                        .failure(
                            failure: mutationFailure(from: error)
                        )
                    )
                )
            }
        }
    }

    private func handleDeleteWorkspace(_ payload: DeleteWorkspaceEvent, reply: (@Sendable (Event) -> Void)?) {
        guard let reply else { return }

        Task { @MainActor in
            do {
                try await workspace.deleteWorkspace(
                    id: payload.workspaceID
                )

                reply(
                    .workspaceMutationAcknowledged(
                        .success(workspaceID: payload.workspaceID)
                    )
                )
            } catch {
                reply(
                    .workspaceMutationAcknowledged(
                        .failure(failure: mutationFailure(from: error))
                    )
                )
            }
        }
    }

    private func handleArchiveWorkspace(_ payload: ArchiveWorkspaceEvent, reply: (@Sendable (Event) -> Void)?) {
        guard let reply else { return }

        Task { @MainActor in
            do {
                try await workspace.archiveWorkspace(id: payload.workspaceID)

                reply(
                    .workspaceMutationAcknowledged(
                        .success(workspaceID: payload.workspaceID)
                    )
                )
            } catch {
                reply(
                    .workspaceMutationAcknowledged(
                        .failure(failure: mutationFailure(from: error))
                    )
                )
            }
        }
    }

    private func handleUnarchiveWorkspace(_ payload: UnarchiveWorkspaceEvent, reply: (@Sendable (Event) -> Void)?) {
        guard let reply else { return }

        Task { @MainActor in
            do {
                try await workspace.unarchiveWorkspace(id: payload.workspaceID)

                reply(
                    .workspaceMutationAcknowledged(
                        .success(workspaceID: payload.workspaceID)
                    )
                )
            } catch {
                reply(
                    .workspaceMutationAcknowledged(
                        .failure(failure: mutationFailure(from: error))
                    )
                )
            }
        }
    }

    private func handleSwitchWorkspace(_ payload: SwitchWorkspaceEvent, reply: (@Sendable (Event) -> Void)?) {
        guard let reply else { return }

        Task { @MainActor in
            do {
                try await workspace.activateWorkspace(id: payload.workspaceID)

                reply(
                    .workspaceMutationAcknowledged(
                        .success(workspaceID: payload.workspaceID)
                    )
                )
            } catch {
                reply(
                    .workspaceMutationAcknowledged(
                        .failure(
                            failure: mutationFailure(from: error)
                        )
                    )
                )
            }
        }
    }

    private func handleStopWorkspace(_ payload: StopWorkspaceEvent, reply: (@Sendable (Event) -> Void)?) {
        guard let reply else { return }

        Task { @MainActor in
            do {
                guard workspace.activeWorkspaceID == payload.workspaceID else {
                    reply(
                        .workspaceMutationAcknowledged(
                            .failure(
                                failure: .workspaceNotActive(payload.workspaceID)
                            )
                        )
                    )

                    return
                }

                try await workspace.stopActiveWorkspace()

                reply(
                    .workspaceMutationAcknowledged(
                        .success(
                            workspaceID: payload.workspaceID
                        )
                    )
                )
            } catch {
                reply(
                    .workspaceMutationAcknowledged(
                        .failure(
                            failure: mutationFailure(from: error)
                        )
                    )
                )
            }
        }
    }

    private func mutationFailure(
        from error: Error
    ) -> WorkspaceMutationAcknowledgement.Failure {
        if let error = error as? SettingsStoreError {
            return error.mutationFailure
        }

        if error is SettingsRepositoryError {
            return .persistence
        }

        return .unexpected
    }

    private func accepts(_ event: Event, reply: (@Sendable (Event) -> Void)?) -> Bool {
        guard event.isWorkspaceMutation else {
            return true
        }

        guard lifecycle.acceptsMutations else {
            reply?(
                .workspaceMutationAcknowledged(
                    .failure(failure: .updateInProgress)
                )
            )

            return false
        }

        return true
    }
}

extension Event {
    fileprivate var isWorkspaceMutation: Bool {
        switch self {
            case .createWorkspace,
                 .updateWorkspace,
                 .deleteWorkspace,
                 .archiveWorkspace,
                 .unarchiveWorkspace,
                 .switchWorkspace,
                 .stopWorkspace:
                true

            default:
                false
            }
        }
}
