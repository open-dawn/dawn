//
//  MenuBarVisibilityEvents.swift
//  dawn
//
//  Created by Rafael Venetikides on 28/10/26.
//

import Foundation

public struct GetMenuBarVisibilityEvent: Codable, Sendable, Equatable {
    public init() {}
}

public struct SetMenuBarVisibilityEvent: Codable, Sendable, Equatable {
    public let isVisible: Bool

    public init(isVisible: Bool) {
        self.isVisible = isVisible
    }
}

public struct MenuBarVisibilityStateEvent: Codable, Sendable, Equatable {
    public let isVisible: Bool

    public init(isVisible: Bool) {
        self.isVisible = isVisible
    }
}

public enum MenuBarVisibilityMutationAcknowledgement: Codable, Sendable, Equatable {
    public enum Failure: Codable, Sendable, Equatable {
        case persistence
        case unexpected
    }

    case success(isVisible: Bool)
    case failure(Failure)
}

extension MenuBarVisibilityMutationAcknowledgement.Failure: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .persistence:
            "DAWN couldn't save the menu bar setting."
        case .unexpected:
            "DAWN couldn't update the menu bar setting."
        }
    }
}
