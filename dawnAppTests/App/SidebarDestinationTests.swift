@testable import dawnApp
import Testing

@Suite("Sidebar destination")
struct SidebarDestinationTests {
    @Test("initial destination is one of the sidebar destinations")
    func initialDestinationIsListed() {
        #expect(SidebarDestination.allCases.contains(SidebarDestination.initial))
    }

    @Test("destinations are unique and hashable")
    func destinationsAreUnique() {
        let destinations = SidebarDestination.allCases

        #expect(Set(destinations).count == destinations.count)
        #expect(Set(destinations.map(\.id)).count == destinations.count)
    }

    @Test("equal destinations compare and hash equally")
    func destinationsAreHashable() {
        var destinations: Set<SidebarDestination> = [.profiles]

        destinations.insert(.profiles)
        destinations.insert(.about)

        #expect(destinations == [.profiles, .about])
        #expect(SidebarDestination.profiles != SidebarDestination.settings)
    }

    @Test("every destination has a unique title and a system image")
    func destinationsHaveLabels() {
        let titles = SidebarDestination.allCases.map(\.title)

        #expect(Set(titles).count == titles.count)
        #expect(titles.allSatisfy { !$0.isEmpty })
        #expect(SidebarDestination.allCases.allSatisfy { !$0.systemImage.isEmpty })
    }
}