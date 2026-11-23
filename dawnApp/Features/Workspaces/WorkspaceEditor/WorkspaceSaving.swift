//
//  WorkspaceSaving.swift
//  dawn
//
//  Created by Rafael Venetikides on 24/09/26.
//

import Foundation
import libdawn

@MainActor
protocol WorkspaceSaving: AnyObject {
    @discardableResult
    func createWorkspace(
        name: String,
        symbol: String,
        applications: [WorkspaceApplication],
        transition: WorkspaceTransition
    ) async throws -> UUID

    func updateWorkspace(_ workspace: Workspace) async throws
}

extension SettingsWorkspaceStore: WorkspaceSaving {}
