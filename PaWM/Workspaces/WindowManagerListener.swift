import PaEventKit

@MainActor
protocol ContextSwitching {
    func switchToContext(to context: WorkspaceContext)
}

@MainActor
struct DefaultContextSwitching: ContextSwitching {
    func switchToContext(to context: WorkspaceContext) {
        let appsList: [WorkspaceApplication] = context.applications

        Task { @MainActor in
            do {
                try await WMActionIdentifier.resetWindows.action.execute()
            } catch {
                print("Error: \(error.localizedDescription)")
            }

            for app in appsList {
                do {
                    try await WMActionIdentifier.openApp(app).action.execute()
                } catch {
                    print("Error: \(error.localizedDescription)")
                }
            }
        }
    }
}

@MainActor
final class WindowManagerListener: Listener {
    private let contextManager: ContextProviding
    private let contextSwitching: ContextSwitching

    init(
        bus: PaEventBus,
        contextManager: ContextProviding,
        contextSwitching: ContextSwitching = DefaultContextSwitching()
    ) {
        self.contextManager = contextManager
        self.contextSwitching = contextSwitching
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

    convenience init(bus: PaEventBus) async throws {
        let publisher = EventBusContextSnapshotPublisher(bus: bus)

        try await self.init(bus: bus, contextManager: ContextManager(snapshotPublisher: publisher))
    }

    func handle(_ event: PaEvent, reply: (@Sendable (PaEvent) -> Void)?) {
        switch event {
        case .switchSpace(let payload):
            Task { @MainActor in
                guard let context = await getContextWithIndex(payload.spaceIndex) else { return }
                contextSwitching.switchToContext(to: context)
            }

        case .getContexts:
            Task { @MainActor in
                let contexts = await getAllContexts()
                reply?(.contextsFetched(PaContextsFetchedEvent(contexts: contexts)))
            }

        case .initialized:
            print("PaWM initialized")

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
        await contextManager.getAvailableContexts()
    }

    private func handleCreateContext(_ payload: PaCreateContextEvent, reply: (@Sendable (PaEvent) -> Void)?) {
        guard let reply else { return }

        Task { @MainActor in
            do {
                let context = try await contextManager.createContext(
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

    private func handleUpdateContext(_ payload: PaUpdateContextEvent, reply: (@Sendable (PaEvent) -> Void)?) {
        guard let reply else { return }

        Task { @MainActor in
            do {
                try await contextManager.updateContext(
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

    private func handleDeleteContext(_ payload: PaDeleteContextEvent, reply: (@Sendable (PaEvent) -> Void)?) {
        guard let reply else { return }

        Task { @MainActor in
            do {
                try await contextManager.deleteContext(
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

    private func handleSwitchContext(_ payload: PaSwitchContextEvent, reply: (@Sendable (PaEvent) -> Void)?) {
        guard let reply else { return }

        Task { @MainActor in
            guard let context = await contextManager.getContext(
                id: payload.contextID
            ) else {
                reply(
                    .contextMutationAcknowledged(
                        .failure(
                            failure: .contextNotFound(
                                payload.contextID
                            )
                        )
                    )
                )

                return
            }

            contextSwitching.switchToContext(to: context)

            reply(
                .contextMutationAcknowledged(
                    .success(contextID: context.id)
                )
            )
        }
    }

    private func mutationFailure(
        from error: Error
    ) -> PaContextMutationAcknowledgement.Failure {
        if let error = error as? SettingsStoreError {
            return switch error {
            case .emptyContextName: .emptyContextName

            case .emptyContextSymbol: .emptyContextSymbol

            case .emptyApplicationBundleIdentifier: .emptyApplicationBundleIdentifier

            case .emptyApplicationDisplayName: .emptyApplicationDisplayName

            case .duplicateApplication(let bundleIdentifier): .duplicateApplication(bundleIdentifier: bundleIdentifier)

            case .duplicateContextIdentifier(let id): .duplicateContextIdentifier(id)

            case .duplicateApplicationIdentifier(let id): .duplicateApplicationIdentifier(id)

            case .contextNotFound(let id): .contextNotFound(id)
            }
        }

        if error is SettingsRepositoryError {
            return .persistence
        }

        return .unexpected
    }
}
