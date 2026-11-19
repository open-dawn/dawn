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
            availableContexts: []
        )

        #expect(!requiresRefresh)
        #expect(model.selectedDestination == .settings)
        #expect(model.pendingRoute == nil)
    }

    @Test("known context routes navigate immediately")
    func knownContextRoute() {
        let context = WorkspaceContext(
            name: "Work",
            symbol: "briefcase"
        )
        let model = AppNavigationModel()

        let requiresRefresh = model.receive(
            .context(context.id),
            availableContexts: [context]
        )

        #expect(!requiresRefresh)
        #expect(model.selectedDestination == .context(context.id))
        #expect(model.pendingRoute == nil)
    }

    @Test("missing context waits for an updated snapshot")
    func pendingContextAppears() {
        let context = WorkspaceContext(
            name: "Work",
            symbol: "briefcase"
        )
        let model = AppNavigationModel()

        let requiresRefresh = model.receive(
            .context(context.id),
            availableContexts: []
        )

        #expect(requiresRefresh)
        #expect(model.pendingRoute == .context(context.id))

        model.contextsDidChange([context])

        #expect(
            model.selectedDestination == .context(context.id)
        )
        #expect(model.pendingRoute == nil)
    }

    @Test("unknown context produces a navigation error")
    func unknownContextRoute() {
        let contextID = UUID()
        let model = AppNavigationModel()

        model.receive(
            .context(contextID),
            availableContexts: []
        )

        model.contextRefreshSucceeded(with: [])

        #expect(
            model.error == .contextNotFound(contextID)
        )
        #expect(model.pendingRoute == nil)
        #expect(model.selectedDestination == nil)
    }

    @Test("failed refresh produces an availability error")
    func contextRefreshFailure() {
        let model = AppNavigationModel()

        model.receive(
            .context(UUID()),
            availableContexts: []
        )

        model.contextRefreshFailed()

        #expect(model.error == .contextsUnavailable)
        #expect(model.pendingRoute == nil)
    }

    @Test("selects the first active workspace when nothing is selected")
    func selectsInitialWorkspace() {
        let first = WorkspaceContext(name: "Work", symbol: "briefcase")
        let second = WorkspaceContext(name: "Home", symbol: "house")
        let archived = WorkspaceContext(
            name: "Old",
            symbol: "archivebox",
            isArchived: true
        )
        let model = AppNavigationModel()

        model.selectInitialWorkspaceIfNeeded(from: [archived, first, second])

        #expect(model.selectedDestination == .context(first.id))
    }

    @Test("does not override an existing selection")
    func keepsExistingSelection() {
        let first = WorkspaceContext(name: "Work", symbol: "briefcase")
        let second = WorkspaceContext(name: "Home", symbol: "house")
        let model = AppNavigationModel()
        model.selectedDestination = .settings

        model.selectInitialWorkspaceIfNeeded(from: [first, second])

        #expect(model.selectedDestination == .settings)
    }

    @Test("leaves selection empty when there are no active workspaces")
    func emptyWhenNoActiveWorkspaces() {
        let archived = WorkspaceContext(
            name: "Old",
            symbol: "archivebox",
            isArchived: true
        )
        let model = AppNavigationModel()

        model.selectInitialWorkspaceIfNeeded(from: [archived])

        #expect(model.selectedDestination == nil)
    }
}
