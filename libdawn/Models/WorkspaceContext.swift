//
//  Workspace.swift
//  pineapplewm
//
//  Created by Rafael Venetikides on 19/08/26.
//

import Foundation

public struct WorkspaceContext: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var name: String
    public var symbol: String
    public var applications: [WorkspaceApplication]

    public init(
        id: UUID = UUID(),
        name: String,
        symbol: String,
        applications: [WorkspaceApplication] = []
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.applications = applications
    }
}
