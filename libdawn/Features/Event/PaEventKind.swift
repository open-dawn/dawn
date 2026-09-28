public enum PaEventKind: String, Codable, Sendable, Hashable, CaseIterable {
    case debugPing
    case debugPong
    case switchSpace
    case initialized
    case getContexts
    case contextsFetched
    case createContext
    case updateContext
    case deleteContext
    case switchContext
    case contextMutationAcknowledged
    case availableContexts
}
