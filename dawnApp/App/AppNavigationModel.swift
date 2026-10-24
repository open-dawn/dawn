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
    case contextNotFound(UUID)
    case contextsUnavailable

    var errorDescription: String? {
        switch self {
        case .contextNotFound:
            "The requested context is no longer available."
        case .contextsUnavailable:
            "DAWN couldn't load your contexts. Try again."
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
    func receive(_ route: DawnAppRoute, availableContexts: [WorkspaceContext]) -> Bool {
        pendingRoute = nil
        error = nil

        switch route {
        case .application:
            return false

        case .settings:
            selectedDestination = .settings
            return false

        case .context(let contextID):
            if containsContext(
                contextID,
                in: availableContexts
            ) {
                selectedDestination = .context(contextID)
                return false
            }

            pendingRoute = route
            return true
        }
    }

    func contextsDidChange(_ contexts: [WorkspaceContext]) {
        selectedDestination = selectedDestination?.reconciled(with: contexts)

        guard case .context(let contextID) = pendingRoute,
              containsContext(contextID, in: contexts)
        else {
            return
        }

        pendingRoute = nil
        error = nil
        selectedDestination = .context(contextID)
    }

    func contextRefreshSucceeded(with contexts: [WorkspaceContext]) {
        guard case .context(let contextID) = pendingRoute else {
            return
        }

        pendingRoute = nil

        guard containsContext(contextID, in: contexts) else {
            error = .contextNotFound(contextID)
            return
        }

        error = nil
        selectedDestination = .context(contextID)
    }

    func contextRefreshFailed() {
        guard pendingRoute != nil else {
            return
        }

        pendingRoute = nil
        error = .contextsUnavailable
    }

    func dismissError() {
        error = nil
    }

    private func containsContext(_ contextID: UUID, in contexts: [WorkspaceContext]) -> Bool {
        contexts.contains {
            $0.id == contextID
        }
    }
}
