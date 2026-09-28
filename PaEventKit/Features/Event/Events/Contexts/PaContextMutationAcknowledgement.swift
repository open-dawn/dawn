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

extension PaContextMutationAcknowledgement.Failure: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .emptyContextName:
            "The context name cannot be empty."
        case .emptyContextSymbol:
            "The context symbol cannot be empty."
        case .emptyApplicationBundleIdentifier:
            "An application has no bundle identifier."
        case .emptyApplicationDisplayName:
            "An application has no display name."
        case let .duplicateApplication(bundleIdentifier):
            "The application \(bundleIdentifier) was added more than once."
        case .duplicateContextIdentifier:
            "A context with this identifier already exists."
        case .duplicateApplicationIdentifier:
            "An application with this identifier already exists."
        case .contextNotFound:
            "The selected context no longer exists."
        case .persistence:
            "Workspace manager could not save the changes."
        case .unexpected:
            "Workspace manager could not complete the request."
        }
    }
}
