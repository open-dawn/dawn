public enum EventAskError: Error, Equatable, Sendable {
    case noHandler
    case timeout
}
