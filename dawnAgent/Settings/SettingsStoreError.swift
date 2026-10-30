//
//  SettingsStoreError.swift
//  dawn
//
//  Created by Rafael Venetikides on 20/08/26.
//

import Foundation
import libdawn

enum SettingsStoreError: Error, Equatable, Sendable {
    case emptyContextName
    case emptyContextSymbol
    case emptyApplicationBundleIdentifier
    case emptyApplicationDisplayName
    case duplicateApplication(bundleIdentifier: String)
    case duplicateContextIdentifier(UUID)
    case duplicateApplicationIdentifier(UUID)
    case contextNotFound(UUID)
    case contextArchived(UUID)

    var localizedDescription: String {
        switch self {
        case .emptyContextName: "The context name cannot be empty."
        case .emptyContextSymbol: "The context symbol cannot be empty."
        case .emptyApplicationBundleIdentifier: "The application bundle identifier cannot be empty."
        case .emptyApplicationDisplayName: "The application display name cannot be empty."
        case let .duplicateApplication(bundleIdentifier):
            "An application with the bundle identifier '\(bundleIdentifier)' already exists."
        case let .duplicateContextIdentifier(id): "A context with the identifier '\(id.uuidString)' already exists."
        case let .duplicateApplicationIdentifier(id):
            "An application with the identifier '\(id.uuidString)' already exists."
        case let .contextNotFound(id): "No context was found with the identifier '\(id.uuidString)'."
        case let .contextArchived(id): "The context with the identifier '\(id.uuidString)' is archived."
        }
    }

    var mutationFailure: ContextMutationAcknowledgement.Failure {
        switch self {
        case .emptyContextName: .emptyContextName
        case .emptyContextSymbol: .emptyContextSymbol
        case .emptyApplicationBundleIdentifier: .emptyApplicationBundleIdentifier
        case .emptyApplicationDisplayName: .emptyApplicationDisplayName
        case let .duplicateApplication(bundleIdentifier): .duplicateApplication(bundleIdentifier: bundleIdentifier)
        case let .duplicateContextIdentifier(id): .duplicateContextIdentifier(id)
        case let .duplicateApplicationIdentifier(id): .duplicateApplicationIdentifier(id)
        case let .contextNotFound(id): .contextNotFound(id)
        case let .contextArchived(id): .contextArchived(id)
        }
    }
}
