//
//  ContextCreationRequest.swift
//  dawn
//
//  Created by Longhi on 03/11/26.
//

import Foundation
import libdawn

public enum ContextCreationModal: Hashable, Sendable {
    case operationError
    case applicationImporter
}

public struct ContextCreationRequest: Equatable, Sendable {
    public let name: String
    public let symbolName: String
    public let applications: [ContextCreationApplication]
    public let activationPolicy: WorkspaceActivationPolicy

    public var transition: WorkspaceTransition {
        WorkspaceTransition(activationPolicy: activationPolicy)
    }

    public init(
        name: String,
        symbolName: String,
        applications: [ContextCreationApplication],
        activationPolicy: WorkspaceActivationPolicy
    ) {
        self.name = name
        self.symbolName = symbolName
        self.applications = applications
        self.activationPolicy = activationPolicy
    }
}
