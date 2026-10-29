//
//  WorkspaceContextManaging.swift
//  dawn
//
//  Created by Rafael Venetikides on 23/09/26.
//

import Foundation
import libdawn

@MainActor
protocol WorkspaceContextManaging: AnyObject {
    func switchContext(id: UUID) async throws
    func deleteContext(id: UUID) async throws
    func updateContext(_ context: WorkspaceContext) async throws
}

extension SettingsContextStore: WorkspaceContextManaging {}
