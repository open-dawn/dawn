//
//  ComponentIdentity.swift
//  dawn
//
//  Created by Rafael Venetikides on 11/11/26.
//

public struct ComponentIdentity: Codable, Sendable, Equatable {
    public let identifier: String
    public let version: String
    public let build: String

    public init(identifier: String, version: String, build: String) {
        self.identifier = identifier
        self.version = version
        self.build = build
    }
}
