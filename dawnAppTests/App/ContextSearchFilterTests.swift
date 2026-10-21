@testable import dawnApp
import libdawn
import Testing

@Suite("Context search filter")
struct ContextSearchFilterTests {
    private let contexts = [
        WorkspaceContext(name: "Apple Developer Academy", symbol: "apple.logo"),
        WorkspaceContext(name: "Gaming", symbol: "gamecontroller.fill"),
        WorkspaceContext(name: "Study", symbol: "book.fill")
    ]

    @Test("empty search returns every context in order")
    func emptySearchReturnsAll() {
        #expect(ContextSearchFilter.filter(contexts, searchText: "") == contexts)
        #expect(ContextSearchFilter.filter(contexts, searchText: "   ") == contexts)
    }

    @Test("search matches names case-insensitively")
    func searchIsCaseInsensitive() {
        #expect(
            ContextSearchFilter.filter(contexts, searchText: "gaming")
                == [contexts[1]]
        )
        #expect(
            ContextSearchFilter.filter(contexts, searchText: "APPLE")
                == [contexts[0]]
        )
        #expect(
            ContextSearchFilter.filter(contexts, searchText: "sTuDy")
                == [contexts[2]]
        )
    }

    @Test("search matches substrings and trims whitespace")
    func searchMatchesSubstrings() {
        #expect(
            ContextSearchFilter.filter(contexts, searchText: "  developer ")
                == [contexts[0]]
        )
        #expect(
            ContextSearchFilter.filter(contexts, searchText: "a")
                == [contexts[0], contexts[1]]
        )
    }

    @Test("search with no matches returns an empty list")
    func searchWithoutMatchesIsEmpty() {
        #expect(ContextSearchFilter.filter(contexts, searchText: "xyz").isEmpty)
    }

    @Test("clearing the search restores all contexts")
    func clearingSearchRestoresAll() {
        let filtered = ContextSearchFilter.filter(contexts, searchText: "gaming")

        #expect(filtered == [contexts[1]])
        #expect(ContextSearchFilter.filter(contexts, searchText: "") == contexts)
    }

    @Test("a selection that remains in the filtered results is preserved")
    func selectionSurvivesFiltering() {
        let gaming = contexts[1]
        let filtered = ContextSearchFilter.filter(contexts, searchText: "gam")

        #expect(filtered.contains(gaming))
        #expect(
            SidebarDestination.context(gaming.id).reconciled(with: contexts)
                == .context(gaming.id)
        )
    }
}
