public enum PaEventKind: String, Codable, Sendable, Hashable, CaseIterable {
    case debugPing
    case debugPong
    case switchSpace
    case initializedEvent
    case getContextsEvent
    case contextsFetchedEvent
}
