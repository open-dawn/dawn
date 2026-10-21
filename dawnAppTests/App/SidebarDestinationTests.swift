@testable import dawnApp
import Foundation
import libdawn
import Testing

@Suite("Sidebar destination")
struct SidebarDestinationTests {
    @Test("context destinations expose their stable context identifier")
    func contextDestinationExposesID() {
        let context = WorkspaceContext(name: "Work", symbol: "briefcase")

        #expect(SidebarDestination.context(context.id).contextID == context.id)
        #expect(SidebarDestination.settings.contextID == nil)
        #expect(SidebarDestination.about.contextID == nil)
    }

    @Test("context destinations with the same identifier are equal and hash equally")
    func contextDestinationsAreHashable() {
        let id = UUID()
        var destinations: Set<SidebarDestination> = [.context(id)]

        destinations.insert(.context(id))
        destinations.insert(.context(UUID()))
        destinations.insert(.about)

        #expect(destinations.count == 3)
        #expect(SidebarDestination.context(id) != SidebarDestination.settings)
    }

    @Test("reconciliation keeps a context destination whose context still exists")
    func reconciliationKeepsExistingContext() {
        let work = WorkspaceContext(name: "Work", symbol: "briefcase")
        let personal = WorkspaceContext(name: "Personal", symbol: "person")
        let destination = SidebarDestination.context(work.id)

        #expect(destination.reconciled(with: [work, personal]) == destination)
    }

    @Test("reconciliation after a refresh keeps the selection when the context remains")
    func reconciliationAfterRefreshKeepsSelection() {
        let work = WorkspaceContext(name: "Work", symbol: "briefcase")
        let refreshedWork = WorkspaceContext(id: work.id, name: "Work (renamed)", symbol: "case")
        let gaming = WorkspaceContext(name: "Gaming", symbol: "gamecontroller.fill")

        let afterRefresh: [WorkspaceContext] = [refreshedWork, gaming]

        #expect(
            SidebarDestination.context(work.id).reconciled(with: afterRefresh)
                == .context(work.id)
        )
    }

    @Test("reconciliation after deletion clears the selection")
    func reconciliationAfterDeletionClearsSelection() {
        let work = WorkspaceContext(name: "Work", symbol: "briefcase")
        let personal = WorkspaceContext(name: "Personal", symbol: "person")
        let destination = SidebarDestination.context(work.id)

        #expect(destination.reconciled(with: [personal]) == nil)
        #expect(destination.reconciled(with: []) == nil)
    }

    @Test("each destination routes to a distinct target")
    func destinationsRouteDistinctly() {
        let work = WorkspaceContext(name: "Work", symbol: "briefcase")
        let personal = WorkspaceContext(name: "Personal", symbol: "person")

        let routes: [SidebarDestination] = [
            .context(work.id),
            .context(personal.id),
            .settings,
            .about
        ]

        #expect(Set(routes).count == routes.count)
        #expect(routes.map(\.contextID) == [work.id, personal.id, nil, nil])
    }

    @Test("reconciliation keeps fixed destinations and follows renames by identifier")
    func reconciliationKeepsFixedDestinations() {
        let work = WorkspaceContext(name: "Work", symbol: "briefcase")
        var renamed = work
        renamed.name = "Renamed"

        #expect(SidebarDestination.settings.reconciled(with: []) == .settings)
        #expect(SidebarDestination.about.reconciled(with: []) == .about)
        #expect(
            SidebarDestination.context(work.id).reconciled(with: [renamed])
                == .context(work.id)
        )
    }
}