public enum Event: Codable, Sendable, Equatable {
    case debugPing(DebugPingEvent)
    case debugPong(DebugPongEvent)
    case initialized(InitializedEvent)
    case getContexts(GetContextsEvent)
    case createContext(CreateContextEvent)
    case updateContext(UpdateContextEvent)
    case deleteContext(DeleteContextEvent)
    case switchContext(SwitchContextEvent)
    case contextsFetched(ContextsFetchedEvent)

    case availableContexts(AvailableContextsEvent)

    case contextMutationAcknowledged(ContextMutationAcknowledgement)

    case getMenuBarVisibility(GetMenuBarVisibilityEvent)
    case setMenuBarVisibility(SetMenuBarVisibilityEvent)
    case menuBarVisibilityState(MenuBarVisibilityStateEvent)
    case menuBarVisibilityMutationAcknowledged(MenuBarVisibilityMutationAcknowledgement)

    public var kind: EventKind {
        switch self {
        case .debugPing: .debugPing
        case .debugPong: .debugPong
        case .initialized: .initialized
        case .getContexts: .getContexts
        case .contextsFetched: .contextsFetched
        case .createContext: .createContext
        case .updateContext: .updateContext
        case .deleteContext: .deleteContext
        case .switchContext: .switchContext
        case .contextMutationAcknowledged: .contextMutationAcknowledged
        case .availableContexts: .availableContexts
        case .getMenuBarVisibility: .getMenuBarVisibility
        case .setMenuBarVisibility: .setMenuBarVisibility
        case .menuBarVisibilityState: .menuBarVisibilityState
        case .menuBarVisibilityMutationAcknowledged: .menuBarVisibilityMutationAcknowledged
        }
    }
}
