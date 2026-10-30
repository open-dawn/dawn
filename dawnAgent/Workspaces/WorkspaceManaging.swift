//
//  WorkspaceManaging.swift
//  dawn
//
//  Created by Rafael Venetikides on 26/10/26.
//

import Foundation
import libdawn

public struct WorkspaceSnapshot: Codable, Equatable, Sendable {
    public let contexts: [WorkspaceContext]
    public let activity: WorkspaceActivityState

    public init(contexts: [WorkspaceContext], activity: WorkspaceActivityState) {
        self.contexts = contexts
        self.activity = activity
    }
}

@MainActor
protocol WorkspaceManaging: ContextProviding, WorkspaceActivityManaging {
    func getWorkspaceSnapshot() async -> WorkspaceSnapshot
}
