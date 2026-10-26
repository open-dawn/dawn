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
        }
    }
}
