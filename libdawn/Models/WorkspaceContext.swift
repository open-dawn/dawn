//
//  Workspace.swift
//  dawn
//
//  Created by Rafael Venetikides on 19/08/26.
//

import Foundation

public struct WorkspaceContext: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var name: String
    public var symbol: String
    public var applications: [WorkspaceApplication]
    public var transition: WorkspaceTransition

    public init(
        id: UUID = UUID(),
        name: String,
        symbol: String,
        applications: [WorkspaceApplication] = [],
        transition: WorkspaceTransition = .default
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.applications = applications
        self.transition = transition
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case symbol
        case applications
        case transition
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        symbol = try container.decode(String.self, forKey: .symbol)
        applications = try container.decodeIfPresent([WorkspaceApplication].self, forKey: .applications) ?? []
        transition = try container.decodeIfPresent(WorkspaceTransition.self, forKey: .transition) ?? .default
    }
}
