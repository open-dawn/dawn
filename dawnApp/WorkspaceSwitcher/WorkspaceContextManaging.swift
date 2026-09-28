//
//  WorkspaceContextManaging.swift
//  pineapplewm
//
//  Created by Rafael Venetikides on 23/09/26.
//

import Foundation

@MainActor
protocol WorkspaceContextManaging: AnyObject {
    func switchContext(id: UUID) async throws
    func deleteContext(id: UUID) async throws
}

extension SettingsContextStore: WorkspaceContextManaging {}
