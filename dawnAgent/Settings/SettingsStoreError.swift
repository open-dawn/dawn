//
//  SettingsStoreError.swift
//  dawn
//
//  Created by Rafael Venetikides on 20/08/26.
//

import Foundation
import libdawn

enum SettingsStoreError: Error, Equatable, Sendable {
    case emptyWorkspaceName
    case emptyWorkspaceSymbol
    case emptyApplicationBundleIdentifier
    case emptyApplicationDisplayName
    case duplicateApplication(bundleIdentifier: String)
    case duplicateWorkspaceIdentifier(UUID)
    case duplicateApplicationIdentifier(UUID)
    case workspaceNotFound(UUID)
    case workspaceArchived(UUID)

    var localizedDescription: String {
        switch self {
        case .emptyWorkspaceName: "The workspace name cannot be empty."
        case .emptyWorkspaceSymbol: "The workspace symbol cannot be empty."
        case .emptyApplicationBundleIdentifier: "The application bundle identifier cannot be empty."
        case .emptyApplicationDisplayName: "The application display name cannot be empty."
        case let .duplicateApplication(bundleIdentifier):
            "An application with the bundle identifier '\(bundleIdentifier)' already exists."
        case let .duplicateWorkspaceIdentifier(id): "A workspace with the identifier '\(id.uuidString)' already exists."
        case let .duplicateApplicationIdentifier(id):
            "An application with the identifier '\(id.uuidString)' already exists."
        case let .workspaceNotFound(id): "No workspace was found with the identifier '\(id.uuidString)'."
        case let .workspaceArchived(id): "The workspace with the identifier '\(id.uuidString)' is archived."
        }
    }

    var mutationFailure: WorkspaceMutationAcknowledgement.Failure {
        switch self {
        case .emptyWorkspaceName: .emptyWorkspaceName
        case .emptyWorkspaceSymbol: .emptyWorkspaceSymbol
        case .emptyApplicationBundleIdentifier: .emptyApplicationBundleIdentifier
        case .emptyApplicationDisplayName: .emptyApplicationDisplayName
        case let .duplicateApplication(bundleIdentifier): .duplicateApplication(bundleIdentifier: bundleIdentifier)
        case let .duplicateWorkspaceIdentifier(id): .duplicateWorkspaceIdentifier(id)
        case let .duplicateApplicationIdentifier(id): .duplicateApplicationIdentifier(id)
        case let .workspaceNotFound(id): .workspaceNotFound(id)
        case let .workspaceArchived(id): .workspaceArchived(id)
        }
    }
}
