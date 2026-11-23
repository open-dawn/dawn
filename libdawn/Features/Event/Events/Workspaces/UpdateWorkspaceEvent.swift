//
//  UpdateWorkspaceEvent.swift
//  dawn
//
//  Created by Rafael Venetikides on 21/09/26.
//

public struct UpdateWorkspaceEvent: Codable, Sendable, Equatable {
    public let workspace: Workspace

    public init(workspace: Workspace) {
        self.workspace = workspace
    }
}
