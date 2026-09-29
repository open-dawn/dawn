//
//  SettingsStoreError.swift
//  dawn
//
//  Created by Rafael Venetikides on 20/08/26.
//

import Foundation

enum SettingsStoreError: Error, Equatable, Sendable {
    case emptyContextName
    case emptyContextSymbol
    case emptyApplicationBundleIdentifier
    case emptyApplicationDisplayName
    case duplicateApplication(bundleIdentifier: String)
    case duplicateContextIdentifier(UUID)
    case duplicateApplicationIdentifier(UUID)
    case contextNotFound(UUID)

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
        }
    }
}
