//
//  StopContextEvent.swift
//  dawn
//
//  Created by Rafael Venetikides on 09/11/26.
//

import Foundation

public struct StopContextEvent: Codable, Sendable, Equatable {
    public let contextID: UUID

    public init(contextID: UUID) {
        self.contextID = contextID
    }
}
