import Foundation

public struct WorkspaceApplication: Identifiable, Sendable, Codable, Equatable {
    public let id: UUID
    public var bundleIdentifier: String
    public var displayName: String
    public var applicationURL: URL?
    public var allowsRunningApplicationSubstitution: Bool
    public var createsNewApplicationInstance: Bool
    public var arguments: [String]
    public var environment: [String: String]
    public var promptsUserIfNeeded: Bool

    public init(
        id: UUID = UUID(),
        bundleIdentifier: String,
        displayName: String,
        applicationURL: URL? = nil,
        allowsRunningApplicationSubstitution: Bool = true,
        createsNewApplicationInstance: Bool = false,
        arguments: [String] = [],
        environment: [String: String] = [:],
        promptsUserIfNeeded: Bool = false
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.applicationURL = applicationURL
        self.allowsRunningApplicationSubstitution = allowsRunningApplicationSubstitution
        self.createsNewApplicationInstance = createsNewApplicationInstance
        self.arguments = arguments
        self.environment = environment
        self.promptsUserIfNeeded = promptsUserIfNeeded
    }
}
