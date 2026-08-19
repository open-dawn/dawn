public enum PaEventKind: String, Codable, Sendable, Hashable, CaseIterable {
    case debugPing
    case debugPong
    case switchSpace
}

public enum PaEvent: Codable, Sendable, Equatable {
    case debugPing(PaDebugPingEvent)
    case debugPong(PaDebugPongEvent)
    case switchSpace(PaSwitchSpaceEvent)

    public var kind: PaEventKind {
        switch self {
        case .debugPing:
            .debugPing
        case .debugPong:
            .debugPong
        case .switchSpace:
            .switchSpace
        }
    }
}
