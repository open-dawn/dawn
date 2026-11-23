//
//  WorkspaceActivityManaging.swift
//  dawn
//
//  Created by Rafael Venetikides on 26/10/26.
//

import Foundation
import libdawn

@MainActor
protocol WorkspaceActivityManaging {
    func getWorkspaceActivity() async -> WorkspaceActivityState

    @discardableResult
    func recordWorkspaceActivation(workspaceID: UUID, at date: Date) async throws -> WorkspaceActivityState

    @discardableResult
    func stopActiveWorkspace(at date: Date) async throws -> WorkspaceActivityState
}
