public struct PaContextsFetchedEvent: Codable, Sendable, Equatable {
    public let contexts: [WorkspaceContext]

    public init(contexts: [WorkspaceContext]) {
        self.contexts = contexts
    }
}
