//
//  UpdateEvents.swift
//  dawn
//
//  Created by Rafael Venetikides on 11/11/26.
//

public struct GetComponentIdentityEvent: Codable, Sendable, Equatable {
    public init() {}
}

public struct ComponentIdentityEvent: Codable, Sendable, Equatable {
    public let identity: ComponentIdentity

    public init(identity: ComponentIdentity) {
        self.identity = identity
    }
}

public struct PrepareForApplicationUpdateEvent: Codable, Sendable, Equatable {
    public init() {}
}

public enum ApplicationUpdatePrepAcknowledgement: Codable, Sendable, Equatable {
    public enum Failure: Codable, Sendable, Equatable {
        case workspaceShutdownFailed
        case unexpected
    }

    case ready(identity: ComponentIdentity)
    case failure(failure: Failure)
}
