public struct PaSwitchSpaceEvent: Codable, Sendable, Equatable {
    public let spaceIndex: Int

    public init(spaceIndex: Int) {
        self.spaceIndex = spaceIndex
    }
}
