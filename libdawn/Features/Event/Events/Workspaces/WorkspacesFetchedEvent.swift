public struct WorkspacesFetchedEvent: Codable, Sendable, Equatable {
    public let workspaces: [Workspace]
    public let activity: WorkspaceActivityState

    public init(
        workspaces: [Workspace],
        activity: WorkspaceActivityState = .empty
    ) {
        self.workspaces = workspaces
        self.activity = activity
    }

    private enum CodingKeys: String, CodingKey {
        case workspaces
        case activity
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        workspaces = try container.decode([Workspace].self, forKey: .workspaces)
        activity = try container.decodeIfPresent(
            WorkspaceActivityState.self,
            forKey: .activity
        ) ?? .empty
    }
}
