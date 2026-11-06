public struct AccessibilityStatusEvent: Codable, Sendable, Equatable {
    public let isTrusted: Bool

    public init(isTrusted: Bool) {
        self.isTrusted = isTrusted
    }
}
