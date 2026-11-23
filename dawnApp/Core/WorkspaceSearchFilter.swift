import Foundation
import libdawn

enum WorkspaceSearchFilter {
    static func filter(_ workspaces: [Workspace], searchText: String) -> [Workspace] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return workspaces
        }

        return workspaces.filter { workspace in
            workspace.name.localizedCaseInsensitiveContains(query)
        }
    }
}
