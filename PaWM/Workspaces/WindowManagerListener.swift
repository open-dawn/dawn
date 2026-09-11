import PaEventKit

@MainActor
final class WindowManagerListener: Listener {
    private let contextManager: ContextProviding

    init(bus: PaEventBus, contextManager: ContextProviding = ContextManager()) {
        self.contextManager = contextManager
        bus.addListener(self, kinds: [.switchSpace, .getContexts])
    }

    func handle(_ event: PaEvent, reply: (@Sendable (PaEvent) -> Void)?) {
        switch event {
        case let .switchSpace(payload):
            let context: WorkspaceContext? = getContextWithIndex(payload.spaceIndex)
            guard let context else { return }
            switchToContext(to: context)

        case .getContexts:
            let contexts = getAllContexts()
            reply?(.contextsFetched(PaContextsFetchedEvent(contexts: contexts)))

        // case let .initializedEvent(payload),
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
