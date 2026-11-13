import dawnLogging
import libdawn

@MainActor
protocol ContextSwitching {
    func switchToContext(to context: WorkspaceContext) async throws
}

@MainActor
final class DefaultContextSwitching: ContextSwitching {
    private var tail: Task<Void, Never>?

    func switchToContext(to context: WorkspaceContext) async throws {
        let previous = tail
        let transition = Task { @MainActor in
            await previous?.value
            try await WMActionIdentifier.workspaceTransition(context).action.execute()
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
                .getContexts,
                .createContext,
                .updateContext,
                .deleteContext,
                .archiveContext,
                .unarchiveContext,
                .switchContext,
                .stopContext,
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

        if event.isContextMutation {
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
        case .getContexts:
            Task { @MainActor in
                let contexts = await getAllContexts()

                reply?(
                    .contextsFetched(
                        ContextsFetchedEvent(
                            contexts: contexts,
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
        case .createContext(let payload):
            handleCreateContext(payload, reply: reply)

        case .updateContext(let payload):
            handleUpdateContext(payload, reply: reply)

        case .deleteContext(let payload):
            handleDeleteContext(payload, reply: reply)

        case .archiveContext(let payload):
            handleArchiveContext(payload, reply: reply)

        case .unarchiveContext(let payload):
            handleUnarchiveContext(payload, reply: reply)

        case .switchContext(let payload):
            handleSwitchContext(payload, reply: reply)

        case .stopContext(let payload):
            handleStopContext(payload, reply: reply)

        default:
            return
        }
    }

    func getAllContexts() async -> [WorkspaceContext] {
        await workspace.getAvailableContexts()
    }
}

extension WindowManagerListener {

    private func handleCreateContext(_ payload: CreateContextEvent, reply: (@Sendable (Event) -> Void)?) {
        guard let reply else { return }

        Task { @MainActor in
            do {
                let context = try await workspace.createContext(
                    name: payload.name,
                    symbol: payload.symbol,
                    applications: payload.applications,
                    transition: payload.transition
                )

                reply(
                    .contextMutationAcknowledged(
                        .success(contextID: context.id)
                    )
                )
            } catch {
                reply(
                    .contextMutationAcknowledged(
                        .failure(
                            failure: mutationFailure(from: error)
                        )
                    )
                )
            }
        }
    }

    private func handleUpdateContext(_ payload: UpdateContextEvent, reply: (@Sendable (Event) -> Void)?) {
        guard let reply else { return }

        Task { @MainActor in
            do {
                try await workspace.updateContext(
                    payload.context
                )

                reply(
                    .contextMutationAcknowledged(
                        .success(contextID: payload.context.id)
                    )
                )
            } catch {
                reply(
                    .contextMutationAcknowledged(
                        .failure(
                            failure: mutationFailure(from: error)
                        )
                    )
                )
            }
        }
    }

    private func handleDeleteContext(_ payload: DeleteContextEvent, reply: (@Sendable (Event) -> Void)?) {
        guard let reply else { return }

        Task { @MainActor in
            do {
                try await workspace.deleteContext(
                    id: payload.contextID
                )

                reply(
                    .contextMutationAcknowledged(
                        .success(contextID: payload.contextID)
                    )
                )
            } catch {
                reply(
                    .contextMutationAcknowledged(
                        .failure(failure: mutationFailure(from: error))
                    )
                )
            }
        }
    }

    private func handleArchiveContext(_ payload: ArchiveContextEvent, reply: (@Sendable (Event) -> Void)?) {
        guard let reply else { return }

        Task { @MainActor in
            do {
                try await workspace.archiveContext(id: payload.contextID)

                reply(
                    .contextMutationAcknowledged(
                        .success(contextID: payload.contextID)
                    )
                )
            } catch {
                reply(
                    .contextMutationAcknowledged(
                        .failure(failure: mutationFailure(from: error))
                    )
                )
            }
        }
    }

    private func handleUnarchiveContext(_ payload: UnarchiveContextEvent, reply: (@Sendable (Event) -> Void)?) {
        guard let reply else { return }

        Task { @MainActor in
            do {
                try await workspace.unarchiveContext(id: payload.contextID)

                reply(
                    .contextMutationAcknowledged(
                        .success(contextID: payload.contextID)
                    )
                )
            } catch {
                reply(
                    .contextMutationAcknowledged(
                        .failure(failure: mutationFailure(from: error))
                    )
                )
            }
        }
    }

    private func handleSwitchContext(_ payload: SwitchContextEvent, reply: (@Sendable (Event) -> Void)?) {
        guard let reply else { return }

        Task { @MainActor in
            do {
                try await workspace.activateContext(id: payload.contextID)

                reply(
                    .contextMutationAcknowledged(
                        .success(contextID: payload.contextID)
                    )
                )
            } catch {
                reply(
                    .contextMutationAcknowledged(
                        .failure(
                            failure: mutationFailure(from: error)
                        )
                    )
                )
            }
        }
    }

    private func handleStopContext(_ payload: StopContextEvent, reply: (@Sendable (Event) -> Void)?) {
        guard let reply else { return }

        Task { @MainActor in
            do {
                guard workspace.activeContextID == payload.contextID else {
                    reply(
                        .contextMutationAcknowledged(
                            .failure(
                                failure: .contextNotActive(payload.contextID)
                            )
                        )
                    )

                    return
                }

                try await workspace.stopActiveContext()

                reply(
                    .contextMutationAcknowledged(
                        .success(
                            contextID: payload.contextID
                        )
                    )
                )
            } catch {
                reply(
                    .contextMutationAcknowledged(
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
    ) -> ContextMutationAcknowledgement.Failure {
        if let error = error as? SettingsStoreError {
            return error.mutationFailure
        }

        if error is SettingsRepositoryError {
            return .persistence
        }

        return .unexpected
    }

    private func accepts(_ event: Event, reply: (@Sendable (Event) -> Void)?) -> Bool {
        guard event.isContextMutation else {
            return true
        }

        guard lifecycle.acceptsMutations else {
            reply?(
                .contextMutationAcknowledged(
                    .failure(failure: .updateInProgress)
                )
            )

            return false
        }

        return true
    }
}

extension Event {
    fileprivate var isContextMutation: Bool {
        switch self {
            case .createContext,
                 .updateContext,
                 .deleteContext,
                 .archiveContext,
                 .unarchiveContext,
                 .switchContext,
                 .stopContext:
                true

            default:
                false
            }
        }
}
