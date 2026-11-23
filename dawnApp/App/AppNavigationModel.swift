//
//  AppNavigationModel.swift
//  dawn
//
//  Created by Rafael Venetikides on 22/10/26.
//

import Foundation
import Observation
import libdawn

enum AppNavigationError: Error, Equatable, LocalizedError {
    case workspaceNotFound(UUID)
    case workspacesUnavailable

    var errorDescription: String? {
        switch self {
        case .workspaceNotFound:
            "The requested workspace is no longer available."
        case .workspacesUnavailable:
            "DAWN couldn't load your workspaces. Try again."
        }
    }
}

@Observable
@MainActor
final class AppNavigationModel {
    var selectedDestination: SidebarDestination?

    private(set) var pendingRoute: DawnAppRoute?
    private(set) var error: AppNavigationError?

    @discardableResult
    func receive(_ route: DawnAppRoute, availableWorkspaces: [Workspace]) -> Bool {
        pendingRoute = nil
        error = nil

        switch route {
        case .application:
            return false

        case .settings:
            selectedDestination = .settings
            return false

        case .workspace(let workspaceID):
            if containsWorkspace(
                workspaceID,
                in: availableWorkspaces
            ) {
                selectedDestination = .workspace(workspaceID)
                return false
            }

            pendingRoute = route
            return true
        }
    }

    func workspacesDidChange(_ workspaces: [Workspace]) {
        selectedDestination = selectedDestination?.reconciled(with: workspaces)

        if case .workspace(let workspaceID) = pendingRoute,
           containsWorkspace(workspaceID, in: workspaces)
        {
            pendingRoute = nil
            error = nil
            selectedDestination = .workspace(workspaceID)
            return
        }

        selectInitialWorkspaceIfNeeded(from: workspaces)
    }

    func selectInitialWorkspaceIfNeeded(from workspaces: [Workspace]) {
        guard selectedDestination == nil, pendingRoute == nil, error == nil else {
            return
        }

        let activeWorkspaces = workspaces.filter { !$0.isArchived }
        guard let first = activeWorkspaces.first else {
            return
        }

        selectedDestination = .workspace(first.id)
    }

    func workspaceRefreshSucceeded(with workspaces: [Workspace]) {
        guard case .workspace(let workspaceID) = pendingRoute else {
            return
        }

        pendingRoute = nil

        guard containsWorkspace(workspaceID, in: workspaces) else {
            error = .workspaceNotFound(workspaceID)
            return
        }

        error = nil
        selectedDestination = .workspace(workspaceID)
    }

    func workspaceRefreshFailed() {
        guard pendingRoute != nil else {
            return
        }

        pendingRoute = nil
        error = .workspacesUnavailable
    }

    func dismissError() {
        error = nil
    }

    private func containsWorkspace(_ workspaceID: UUID, in workspaces: [Workspace]) -> Bool {
        workspaces.contains {
            $0.id == workspaceID
        }
    }
}
