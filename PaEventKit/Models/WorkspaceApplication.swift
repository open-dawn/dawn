import Foundation

public struct WorkspaceApplication: Identifiable, Sendable, Codable, Equatable {
    public let id: UUID
    public var bundleIdentifier: String
    public var displayName: String
    public var applicationURL: URL?
    public var createNewInstance: Bool

    public init(
        id: UUID = UUID(),
        bundleIdentifier: String,
        displayName: String,
        applicationURL: URL? = nil,
        createNewInstance: Bool = false
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.applicationURL = applicationURL
        self.createNewInstance = createNewInstance
    }
}
