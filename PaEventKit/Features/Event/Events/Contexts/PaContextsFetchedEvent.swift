public struct PaContextsFetchedEvent: Codable, Sendable, Equatable {
    let contexts: [WorkspaceContext]

    public init(_ contexts: [WorkspaceContext]) {
        self.contexts = contexts
    }
}
