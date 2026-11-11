public struct ContextsFetchedEvent: Codable, Sendable, Equatable {
    public let contexts: [WorkspaceContext]
    public let activity: WorkspaceActivityState

    public init(
        contexts: [WorkspaceContext],
        activity: WorkspaceActivityState = .empty
    ) {
        self.contexts = contexts
        self.activity = activity
    }

    private enum CodingKeys: String, CodingKey {
        case contexts
        case activity
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        contexts = try container.decode([WorkspaceContext].self, forKey: .contexts)
        activity = try container.decodeIfPresent(
            WorkspaceActivityState.self,
            forKey: .activity
        ) ?? .empty
    }
}
