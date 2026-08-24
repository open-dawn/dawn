//
//  Workspace.swift
//  pineapplewm
//
//  Created by Rafael Venetikides on 19/08/26.
//

import Foundation

struct WorkspaceContext: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var name: String
    var symbol: String
    var applications: [WorkspaceApplication]

    init(
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
