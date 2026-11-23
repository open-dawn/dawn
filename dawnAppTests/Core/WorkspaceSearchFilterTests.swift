@testable import dawnApp
import libdawn
import Testing

@Suite("Workspace search filter")
struct WorkspaceSearchFilterTests {
    private let workspaces = [
        Workspace(name: "Apple Developer Academy", symbol: "laptopcomputer"),
        Workspace(name: "Gaming", symbol: "desktopcomputer"),
        Workspace(name: "Study", symbol: "book.fill")
    ]

    @Test("empty search returns every workspace in order")
    func emptySearchReturnsAll() {
        #expect(WorkspaceSearchFilter.filter(workspaces, searchText: "") == workspaces)
        #expect(WorkspaceSearchFilter.filter(workspaces, searchText: "   ") == workspaces)
    }

    @Test("search matches names case-insensitively")
    func searchIsCaseInsensitive() {
        #expect(
            WorkspaceSearchFilter.filter(workspaces, searchText: "gaming")
                == [workspaces[1]]
        )
        #expect(
            WorkspaceSearchFilter.filter(workspaces, searchText: "APPLE")
                == [workspaces[0]]
        )
        #expect(
            WorkspaceSearchFilter.filter(workspaces, searchText: "sTuDy")
                == [workspaces[2]]
        )
    }

    @Test("search matches substrings and trims whitespace")
    func searchMatchesSubstrings() {
        #expect(
            WorkspaceSearchFilter.filter(workspaces, searchText: "  developer ")
                == [workspaces[0]]
        )
        #expect(
            WorkspaceSearchFilter.filter(workspaces, searchText: "a")
                == [workspaces[0], workspaces[1]]
        )
    }

    @Test("search with no matches returns an empty list")
    func searchWithoutMatchesIsEmpty() {
        #expect(WorkspaceSearchFilter.filter(workspaces, searchText: "xyz").isEmpty)
    }

    @Test("clearing the search restores all workspaces")
    func clearingSearchRestoresAll() {
        let filtered = WorkspaceSearchFilter.filter(workspaces, searchText: "gaming")

        #expect(filtered == [workspaces[1]])
        #expect(WorkspaceSearchFilter.filter(workspaces, searchText: "") == workspaces)
    }

    @Test("a selection that remains in the filtered results is preserved")
    func selectionSurvivesFiltering() {
        let gaming = workspaces[1]
        let filtered = WorkspaceSearchFilter.filter(workspaces, searchText: "gam")

        #expect(filtered.contains(gaming))
        #expect(
            SidebarDestination.workspace(gaming.id).reconciled(with: workspaces)
                == .workspace(gaming.id)
        )
    }
}
