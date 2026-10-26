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
    func recordContextActivation(contextID: UUID, at date: Date) async throws -> WorkspaceActivityState

    @discardableResult
    func stopActiveContext(at date: Date) async throws -> WorkspaceActivityState
}
