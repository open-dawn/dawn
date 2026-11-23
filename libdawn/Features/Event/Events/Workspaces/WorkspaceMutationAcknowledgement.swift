//
//  WorkspaceMutationAcknowledgement.swift
//  dawn
//
//  Created by Rafael Venetikides on 21/09/26.
//

import Foundation

public enum WorkspaceMutationAcknowledgement: Codable, Sendable, Equatable {
    public enum Failure: Codable, Sendable, Equatable {
        case emptyWorkspaceName
        case emptyWorkspaceSymbol
        case emptyApplicationBundleIdentifier
        case emptyApplicationDisplayName

        case duplicateApplication(bundleIdentifier: String)

        case duplicateWorkspaceIdentifier(UUID)
        case duplicateApplicationIdentifier(UUID)
        case workspaceNotFound(UUID)
        case workspaceArchived(UUID)
        case workspaceNotActive(UUID)

        case updateInProgress

        case persistence
        case unexpected
    }

    case success(workspaceID: UUID)

    case failure(failure: Failure)
}

extension WorkspaceMutationAcknowledgement.Failure: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .emptyWorkspaceName:
            "The workspace name cannot be empty."
        case .emptyWorkspaceSymbol:
            "The workspace symbol cannot be empty."
        case .emptyApplicationBundleIdentifier:
            "An application has no bundle identifier."
        case .emptyApplicationDisplayName:
            "An application has no display name."
        case let .duplicateApplication(bundleIdentifier):
            "The application \(bundleIdentifier) was added more than once."
        case .duplicateWorkspaceIdentifier:
            "A workspace with this identifier already exists."
        case .duplicateApplicationIdentifier:
            "An application with this identifier already exists."
        case .workspaceNotFound:
            "The selected workspace no longer exists."
        case .workspaceArchived:
            "The selected workspace is archived."
        case .updateInProgress:
            "Dawn is preparing to install an update"
        case .persistence:
            "Workspace manager could not save the changes."
        case .unexpected:
            "Workspace manager could not complete the request."
        case .workspaceNotActive:
            "The selected workspace is no longer active."
        }
    }
}
