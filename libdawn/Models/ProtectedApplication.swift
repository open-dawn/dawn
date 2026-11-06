import Foundation

public struct ProtectedApplication: Identifiable, Sendable, Codable, Equatable {
    public let id: UUID
    public var bundleIdentifier: String
    public var displayName: String

    public init(
        id: UUID = UUID(),
        bundleIdentifier: String,
        displayName: String,
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
    }
}
