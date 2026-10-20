import Foundation
import libdawn

enum ContextSearchFilter {
    static func filter(_ contexts: [WorkspaceContext], searchText: String) -> [WorkspaceContext] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return contexts
        }

        return contexts.filter { context in
            context.name.localizedCaseInsensitiveContains(query)
        }
    }
}
