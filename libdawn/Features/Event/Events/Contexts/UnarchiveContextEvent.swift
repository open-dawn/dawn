//
//  UnarchiveContextEvent.swift
//  dawn
//
//  Created by Rafael Venetikides on 21/09/26.
//

import Foundation

public struct UnarchiveContextEvent: Codable, Sendable, Equatable {
    public let contextID: UUID

    public init(contextID: UUID) {
        self.contextID = contextID
    }
}
