//
//  CreateContextEvent.swift
//  dawn
//
//  Created by Rafael Venetikides on 21/09/26.
//

public struct CreateContextEvent: Codable, Sendable, Equatable {
    public let name: String
    public let symbol: String
    public let applications: [WorkspaceApplication]
    public let transition: WorkspaceTransition

    public init(
        name: String,
        symbol: String,
        applications: [WorkspaceApplication],
        transition: WorkspaceTransition = .default
    ) {
        self.name = name
        self.symbol = symbol
        self.applications = applications
        self.transition = transition
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case symbol
        case applications
        case transition
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        symbol = try container.decode(String.self, forKey: .symbol)
        applications = try container.decode(
            [WorkspaceApplication].self,
            forKey: .applications
        )
        transition = try container.decodeIfPresent(
            WorkspaceTransition.self,
            forKey: .transition
        ) ?? .default
    }
}
