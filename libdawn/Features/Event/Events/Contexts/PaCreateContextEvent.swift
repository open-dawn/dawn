//
//  PaCreateContextEvent.swift
//  pineapplewm
//
//  Created by Rafael Venetikides on 21/09/26.
//

public struct PaCreateContextEvent: Codable, Sendable, Equatable {
    public let name: String
    public let symbol: String
    public let applications: [WorkspaceApplication]

    public init(name: String, symbol: String, applications: [WorkspaceApplication]) {
        self.name = name
        self.symbol = symbol
        self.applications = applications
    }
}
