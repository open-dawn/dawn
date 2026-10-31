public struct SettingsFetchedEvent: Codable, Sendable, Equatable {
    public let settings: Settings

    public init(settings: Settings) {
        self.settings = settings
    }
}
