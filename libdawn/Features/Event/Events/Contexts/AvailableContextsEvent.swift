//
//  AvailableContextsEvent.swift
//  dawn
//
//  Created by Rafael Venetikides on 21/09/26.
//

public struct AvailableContextsEvent: Codable, Sendable, Equatable {
    public let contexts: [WorkspaceContext]

    public init(contexts: [WorkspaceContext]) {
        self.contexts = contexts
    }
}
