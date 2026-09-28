public struct SwitchSpaceEvent: Codable, Sendable, Equatable {
    public let spaceIndex: Int

    public init(spaceIndex: Int) {
        self.spaceIndex = spaceIndex
    }
}
