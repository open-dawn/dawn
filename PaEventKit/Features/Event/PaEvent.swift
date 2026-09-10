public enum PaEvent: Codable, Sendable, Equatable {
    case debugPing(PaDebugPingEvent)
    case debugPong(PaDebugPongEvent)
    case switchSpace(PaSwitchSpaceEvent)
    case initialized(PaInitializedEvent)
    case getContexts(PaGetContextsEvent)
    case contextsFetched(PaContextsFetchedEvent)

    public var kind: PaEventKind {
        switch self {
        case .debugPing: .debugPing
        case .debugPong: .debugPong
        case .switchSpace: .switchSpace
        case .initialized: .initialized
        case .getContexts: .getContexts
        case .contextsFetched: .contextsFetched
        }
    }
}
