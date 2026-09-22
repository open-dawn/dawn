public enum PaEvent: Codable, Sendable, Equatable {
    case debugPing(PaDebugPingEvent)
    case debugPong(PaDebugPongEvent)
    case switchSpace(PaSwitchSpaceEvent)
    case initialized(PaInitializedEvent)
    case getContexts(PaGetContextsEvent)
    case createContext(PaCreateContextEvent)
    case updateContext(PaUpdateContextEvent)
    case deleteContext(PaDeleteContextEvent)
    case switchContext(PaSwitchContextEvent)
    case contextsFetched(PaContextsFetchedEvent)

    case availableContexts(PaAvailableContextsEvent)

    case contextMutationAcknowledged(PaContextMutationAcknowledgement)

    public var kind: PaEventKind {
        switch self {
        case .debugPing: .debugPing
        case .debugPong: .debugPong
        case .switchSpace: .switchSpace
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
