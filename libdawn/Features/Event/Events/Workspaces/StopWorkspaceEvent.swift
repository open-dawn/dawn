//
//  StopWorkspaceEvent.swift
//  dawn
//
//  Created by Rafael Venetikides on 09/11/26.
//

import Foundation

public struct StopWorkspaceEvent: Codable, Sendable, Equatable {
    public let workspaceID: UUID

    public init(workspaceID: UUID) {
        self.workspaceID = workspaceID
    }
}
