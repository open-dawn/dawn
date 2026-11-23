//
//  AppWorkspaceManaging.swift
//  dawn
//
//  Created by Rafael Venetikides on 23/09/26.
//

import Foundation
import libdawn

@MainActor
protocol AppWorkspaceManaging: AnyObject {
    func switchWorkspace(id: UUID) async throws
    func deleteWorkspace(id: UUID) async throws
    func archiveWorkspace(id: UUID) async throws
    func unarchiveWorkspace(id: UUID) async throws
    func updateWorkspace(_ workspace: Workspace) async throws
    func stopWorkspace(id: UUID) async throws
}

extension SettingsWorkspaceStore: AppWorkspaceManaging {}
