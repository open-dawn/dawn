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

    init(bus: PaEventBus,
         contextManager: ContextProviding,
         contextSwitching: ContextSwitching = DefaultContextSwitching())
    {
        self.contextManager = contextManager
        self.contextSwitching = contextSwitching
        bus.addListener(self, kinds: [.initialized, .switchSpace, .getContexts])
    }

    convenience init(bus: PaEventBus) async throws {
        try await self.init(bus: bus, contextManager: ContextManager())
    }

    func handle(_ event: PaEvent, reply: (@Sendable (PaEvent) -> Void)?) {
        switch event {
        case let .switchSpace(payload):
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
}
