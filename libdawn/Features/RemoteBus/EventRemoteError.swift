public enum EventRemoteError: Error, Equatable, Sendable {
    case notConnected
    case invalidPayload
}
