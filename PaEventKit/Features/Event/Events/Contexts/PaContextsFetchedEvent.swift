public struct PaContextsFetchedEvent: Codable, Sendable, Equatable {
    let contexts: [WorkspaceContext]

    public init(contexts: [WorkspaceContext]) {
        self.contexts = contexts
    }
}