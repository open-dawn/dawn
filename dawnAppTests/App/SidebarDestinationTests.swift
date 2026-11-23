@testable import dawnApp
import Foundation
import libdawn
import Testing

@Suite("Sidebar destination")
struct SidebarDestinationTests {
    @Test("workspace destinations expose their stable workspace identifier")
    func workspaceDestinationExposesID() {
        let workspace = Workspace(name: "Work", symbol: "briefcase")

        #expect(SidebarDestination.workspace(workspace.id).workspaceID == workspace.id)
        #expect(SidebarDestination.settings.workspaceID == nil)
        #expect(SidebarDestination.about.workspaceID == nil)
    }

    @Test("workspace destinations with the same identifier are equal and hash equally")
    func workspaceDestinationsAreHashable() {
        let id = UUID()
        var destinations: Set<SidebarDestination> = [.workspace(id)]

        destinations.insert(.workspace(id))
        destinations.insert(.workspace(UUID()))
        destinations.insert(.about)

        #expect(destinations.count == 3)
        #expect(SidebarDestination.workspace(id) != SidebarDestination.settings)
    }

    @Test("reconciliation keeps a workspace destination whose workspace still exists")
    func reconciliationKeepsExistingWorkspace() {
        let work = Workspace(name: "Work", symbol: "briefcase")
        let personal = Workspace(name: "Personal", symbol: "person")
        let destination = SidebarDestination.workspace(work.id)

        #expect(destination.reconciled(with: [work, personal]) == destination)
    }

    @Test("reconciliation after a refresh keeps the selection when the workspace remains")
    func reconciliationAfterRefreshKeepsSelection() {
        let work = Workspace(name: "Work", symbol: "briefcase")
        let refreshedWork = Workspace(id: work.id, name: "Work (renamed)", symbol: "case")
        let gaming = Workspace(name: "Gaming", symbol: "desktopcomputer")

        let afterRefresh: [Workspace] = [refreshedWork, gaming]

        #expect(
            SidebarDestination.workspace(work.id).reconciled(with: afterRefresh)
                == .workspace(work.id)
        )
    }

    @Test("reconciliation after deletion clears the selection")
    func reconciliationAfterDeletionClearsSelection() {
        let work = Workspace(name: "Work", symbol: "briefcase")
        let personal = Workspace(name: "Personal", symbol: "person")
        let destination = SidebarDestination.workspace(work.id)

        #expect(destination.reconciled(with: [personal]) == nil)
        #expect(destination.reconciled(with: []) == nil)
    }

    @Test("each destination routes to a distinct target")
    func destinationsRouteDistinctly() {
        let work = Workspace(name: "Work", symbol: "briefcase")
        let personal = Workspace(name: "Personal", symbol: "person")

        let routes: [SidebarDestination] = [
            .workspace(work.id),
            .workspace(personal.id),
            .settings,
            .about
        ]

        #expect(Set(routes).count == routes.count)
        #expect(routes.map(\.workspaceID) == [work.id, personal.id, nil, nil])
    }

    @Test("reconciliation keeps fixed destinations and follows renames by identifier")
    func reconciliationKeepsFixedDestinations() {
        let work = Workspace(name: "Work", symbol: "briefcase")
        var renamed = work
        renamed.name = "Renamed"

        #expect(SidebarDestination.settings.reconciled(with: []) == .settings)
        #expect(SidebarDestination.about.reconciled(with: []) == .about)
        #expect(
            SidebarDestination.workspace(work.id).reconciled(with: [renamed])
                == .workspace(work.id)
        )
    }
}