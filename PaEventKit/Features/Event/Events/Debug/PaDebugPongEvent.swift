public struct PaDebugPongEvent: Codable, Sendable, Equatable {
    public let message: String

    public init(message: String = "pong") {
        self.message = message
    }
}
