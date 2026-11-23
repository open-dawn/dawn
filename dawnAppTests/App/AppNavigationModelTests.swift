//
//  AppNavigationModelTests.swift
//  dawn
//
//  Created by Rafael Venetikides on 22/10/26.
//

import Foundation
import Testing
import libdawn

@testable import dawnApp

@MainActor
@Suite("App navigation model")
struct AppNavigationModelTests {
    @Test("settings routes navigate immediately")
    func settingsRoute() {
        let model = AppNavigationModel()

        let requiresRefresh = model.receive(
            .settings,
            availableWorkspaces: []
        )

        #expect(!requiresRefresh)
        #expect(model.selectedDestination == .settings)
        #expect(model.pendingRoute == nil)
    }

    @Test("known workspace routes navigate immediately")
    func knownWorkspaceRoute() {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )
        let model = AppNavigationModel()

        let requiresRefresh = model.receive(
            .workspace(workspace.id),
            availableWorkspaces: [workspace]
        )

        #expect(!requiresRefresh)
        #expect(model.selectedDestination == .workspace(workspace.id))
        #expect(model.pendingRoute == nil)
    }

    @Test("missing workspace waits for an updated snapshot")
    func pendingWorkspaceAppears() {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )
        let model = AppNavigationModel()

        let requiresRefresh = model.receive(
            .workspace(workspace.id),
            availableWorkspaces: []
        )

        #expect(requiresRefresh)
        #expect(model.pendingRoute == .workspace(workspace.id))

        model.workspacesDidChange([workspace])

        #expect(
            model.selectedDestination == .workspace(workspace.id)
        )
        #expect(model.pendingRoute == nil)
    }

    @Test("unknown workspace produces a navigation error")
    func unknownWorkspaceRoute() {
        let workspaceID = UUID()
        let model = AppNavigationModel()

        model.receive(
            .workspace(workspaceID),
            availableWorkspaces: []
        )

        model.workspaceRefreshSucceeded(with: [])

        #expect(
            model.error == .workspaceNotFound(workspaceID)
        )
        #expect(model.pendingRoute == nil)
        #expect(model.selectedDestination == nil)
    }

    @Test("failed refresh produces an availability error")
    func workspaceRefreshFailure() {
        let model = AppNavigationModel()

        model.receive(
            .workspace(UUID()),
            availableWorkspaces: []
        )

        model.workspaceRefreshFailed()

        #expect(model.error == .workspacesUnavailable)
        #expect(model.pendingRoute == nil)
    }

    @Test("selects the first active workspace when nothing is selected")
    func selectsInitialWorkspace() {
        let first = Workspace(name: "Work", symbol: "briefcase")
        let second = Workspace(name: "Home", symbol: "house")
        let archived = Workspace(
            name: "Old",
            symbol: "archivebox",
            isArchived: true
        )
        let model = AppNavigationModel()

        model.selectInitialWorkspaceIfNeeded(from: [archived, first, second])

        #expect(model.selectedDestination == .workspace(first.id))
    }

    @Test("does not override an existing selection")
    func keepsExistingSelection() {
        let first = Workspace(name: "Work", symbol: "briefcase")
        let second = Workspace(name: "Home", symbol: "house")
        let model = AppNavigationModel()
        model.selectedDestination = .settings

        model.selectInitialWorkspaceIfNeeded(from: [first, second])

        #expect(model.selectedDestination == .settings)
    }

    @Test("leaves selection empty when there are no active workspaces")
    func emptyWhenNoActiveWorkspaces() {
        let archived = Workspace(
            name: "Old",
            symbol: "archivebox",
            isArchived: true
        )
        let model = AppNavigationModel()

        model.selectInitialWorkspaceIfNeeded(from: [archived])

        #expect(model.selectedDestination == nil)
    }
}
