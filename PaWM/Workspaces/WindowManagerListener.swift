import PaEventKit

protocol ContextSwitching {
    func switchToContext(to context: WorkspaceContext)
}

struct DefaultContextSwitching: ContextSwitching {
    func switchToContext(to context: WorkspaceContext) {
        let appsList: [WorkspaceApplication] = context.applications

        do {
            Task {
                try await WMActionIdentifier.resetWindows.action.execute()
            }
        } catch {
            print("Error: \(error.localizedDescription)")
        }

        Task {
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
         contextManager: ContextProviding = ContextManager(),
         contextSwitching: ContextSwitching = DefaultContextSwitching())
    {
        self.contextManager = contextManager
        self.contextSwitching = contextSwitching
        bus.addListener(self, kinds: [.initialized, .switchSpace, .getContexts])
    }

    func handle(_ event: PaEvent, reply: (@Sendable (PaEvent) -> Void)?) {
        switch event {
        case let .switchSpace(payload):
            let context: WorkspaceContext? = getContextWithIndex(payload.spaceIndex)
            guard let context else { return }
            contextSwitching.switchToContext(to: context)

        case .getContexts:
            let contexts = getAllContexts()
            reply?(.contextsFetched(PaContextsFetchedEvent(contexts: contexts)))

        case .initialized:
            print("PaWM initialized")

        default:
            return
        }
    }

    func getContextWithIndex(_ index: Int) -> WorkspaceContext? {
        let allContexts = getAllContexts()
        guard index >= 0, index < allContexts.count else { return nil }
        return allContexts[index]
    }

    func getAllContexts() -> [WorkspaceContext] {
        contextManager.getAvailableContexts()
    }
}
