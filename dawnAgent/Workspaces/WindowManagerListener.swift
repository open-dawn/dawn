import dawnLogging
import libdawn

@MainActor
protocol ContextSwitching {
    func switchToContext(to context: WorkspaceContext) async throws
}

@MainActor
struct DefaultContextSwitching: ContextSwitching {
    func switchToContext(to context: WorkspaceContext) {
        Task { @MainActor in
            do {
                try await WMActionIdentifier.workspaceTransition(context).action.execute()
            } catch {
                #log(
                    "Error running workspace transition: \(error.localizedDescription)",
                    level: .error,
                    category: .general
                )
            }
        }
    }
}

@MainActor
final class WindowManagerListener: Listener {
    private let workspace: any WorkspaceCoordinating

    init(
        bus: EventBus,
        workspace: any WorkspaceCoordinating
    ) {
        self.workspace = workspace
        bus.addListener(
            self,
            kinds: [
                .initialized,
                .switchSpace,
                .getContexts,
                .createContext,
                .updateContext,
                .deleteContext,
                .switchContext,
            ]
        )
    }

    func handle(_ event: Event, reply: (@Sendable (Event) -> Void)?) {
        switch event {
        case let .switchSpace(payload):
            Task { @MainActor in
                guard let context = await getContextWithIndex(payload.spaceIndex) else { return }

                try? await workspace.activateContext(id: context.id)
            }

        case .getContexts:
            Task { @MainActor in
                let contexts = await getAllContexts()
                reply?(.contextsFetched(ContextsFetchedEvent(contexts: contexts)))
            }

        case .initialized:
            #log(
                "dawnAgent initialized",
                level: .info,
                category: .appLifecycle
            )

        case let .createContext(payload):
            handleCreateContext(payload, reply: reply)

        case let .updateContext(payload):
            handleUpdateContext(payload, reply: reply)

        case let .deleteContext(payload):
            handleDeleteContext(payload, reply: reply)

        case let .switchContext(payload):
            handleSwitchContext(payload, reply: reply)

        default:
            return
        }
    }

    func getContextWithIndex(_ index: Int) async -> WorkspaceContext? {
        let allContexts = await getAllContexts()
        guard index >= 0, index < allContexts.count else { return nil }
        return allContexts[index]
    }

    func getAllContexts() async -> [WorkspaceContext] {
        await workspace.getAvailableContexts()
    }

    private func handleCreateContext(_ payload: CreateContextEvent, reply: (@Sendable (Event) -> Void)?) {
        guard let reply else { return }

        Task { @MainActor in
            do {
                let context = try await workspace.createContext(
                    name: payload.name,
                    symbol: payload.symbol,
                    applications: payload.applications
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

    private func mutationFailure(
        from error: Error
    ) -> ContextMutationAcknowledgement.Failure {
        if let error = error as? SettingsStoreError {
            return switch error {
            case .emptyContextName: .emptyContextName
            case .emptyContextSymbol: .emptyContextSymbol
            case .emptyApplicationBundleIdentifier: .emptyApplicationBundleIdentifier
            case .emptyApplicationDisplayName: .emptyApplicationDisplayName
            case let .duplicateApplication(bundleIdentifier): .duplicateApplication(bundleIdentifier: bundleIdentifier)
            case let .duplicateContextIdentifier(id): .duplicateContextIdentifier(id)
            case let .duplicateApplicationIdentifier(id): .duplicateApplicationIdentifier(id)
            case let .contextNotFound(id): .contextNotFound(id)
            }
        }

        if error is SettingsRepositoryError {
            return .persistence
        }

        return .unexpected
    }
}
