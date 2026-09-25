//
//  PaContextMutationAcknowledgement.swift
//  pineapplewm
//
//  Created by Rafael Venetikides on 21/09/26.
//

import Foundation

public enum PaContextMutationAcknowledgement: Codable, Sendable, Equatable {
    public enum Failure: Codable, Sendable, Equatable {
        case emptyContextName
        case emptyContextSymbol
        case emptyApplicationBundleIdentifier
        case emptyApplicationDisplayName

        case duplicateApplication(bundleIdentifier: String)

        case duplicateContextIdentifier(UUID)
        case duplicateApplicationIdentifier(UUID)
        case contextNotFound(UUID)

        case persistence
        case unexpected
    }

    case success(contextID: UUID)

    case failure(failure: Failure)
}
