//
//  ContextCreationRequest.swift
//  dawn
//
//  Created by Longhi on 03/11/26.
//

import Foundation

public enum ContextCreationModal: Hashable, Sendable {
    case operationError
    case applicationImporter
}

public struct ContextCreationRequest: Equatable, Sendable {
    public let name: String
    public let symbolName: String
    public let applications: [ContextCreationApplication]
    public let openingBehavior: ContextOpeningBehavior

    public init(
        name: String,
        symbolName: String,
        applications: [ContextCreationApplication],
        openingBehavior: ContextOpeningBehavior
    ) {
        self.name = name
        self.symbolName = symbolName
        self.applications = applications
        self.openingBehavior = openingBehavior
    }
}
