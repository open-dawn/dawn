//
//  WorkspaceManaging.swift
//  dawn
//
//  Created by Rafael Venetikides on 26/10/26.
//

import Foundation
import libdawn

public struct WorkspaceSnapshot: Codable, Equatable, Sendable {
    public let workspaces: [Workspace]
    public let activity: WorkspaceActivityState

    public init(workspaces: [Workspace], activity: WorkspaceActivityState) {
        self.workspaces = workspaces
        self.activity = activity
    }
}

@MainActor
protocol WorkspaceManaging: WorkspaceProviding, WorkspaceActivityManaging {
    func getWorkspaceSnapshot() async -> WorkspaceSnapshot
}
