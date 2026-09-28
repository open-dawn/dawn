//
//  UpdateContextEvent.swift
//  pineapplewm
//
//  Created by Rafael Venetikides on 21/09/26.
//

public struct UpdateContextEvent: Codable, Sendable, Equatable {
    public let context: WorkspaceContext

    public init(context: WorkspaceContext) {
        self.context = context
    }
}
