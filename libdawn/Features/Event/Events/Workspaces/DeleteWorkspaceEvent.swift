//
//  DeleteWorkspaceEvent.swift
//  dawn
//
//  Created by Rafael Venetikides on 21/09/26.
//

import Foundation

public struct DeleteWorkspaceEvent: Codable, Sendable, Equatable {
    public let workspaceID: UUID

    public init(workspaceID: UUID) {
        self.workspaceID = workspaceID
    }
}
