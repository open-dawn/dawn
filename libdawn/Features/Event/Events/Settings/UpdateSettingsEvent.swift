public struct UpdateSettingsEvent: Codable, Sendable, Equatable {
    public let settings: Settings

    public init(settings: Settings) {
        self.settings = settings
    }
}
