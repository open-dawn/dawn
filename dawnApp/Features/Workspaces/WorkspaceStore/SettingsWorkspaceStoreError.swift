//
//  SettingsWorkspaceStoreError.swift
//  dawn
//
//  Created by Rafael Venetikides on 22/09/26.
//

import libdawn
import Foundation

enum SettingsWorkspaceStoreError: Error, Equatable, LocalizedError {
    case notConnected
    case noHandler
    case timeout
    case invalidPayload
    case unexpectedResponse(EventKind)
    case mutationRejected(WorkspaceMutationAcknowledgement.Failure)
    case unknown

    case workspaceIdentifierMismatch(expected: UUID, received: UUID)

    init(_ error: any Error) {
        if let storeError = error as? Self {
            self = storeError
            return
        }

        if let remoteError = error as? EventRemoteError {
            switch remoteError {
            case .notConnected:
                self = .notConnected

            case .invalidPayload:
                self = .invalidPayload
            }

            return
        }

        if let askError = error as? EventAskError {
            switch askError {
            case .noHandler:
                self = .noHandler
            case .timeout:
                self = .timeout
            }

            return
        }

        self = .unknown
    }

    var errorDescription: String? {
        switch self {
        case .notConnected:
            "Workspace manager is not connected."
        case .noHandler:
            "Workspace manager cannot handle this request."
        case .timeout:
            "Workspace manager did not respond in time."
        case .invalidPayload, .unexpectedResponse:
            "Workspace manager returned an invalid response."
        case .mutationRejected(let failure):
            failure.errorDescription
        case .unknown:
            "An unexpected error occurred."
        case .workspaceIdentifierMismatch:
            "Workspace manager returned the wrong workspace."
        }
    }

    var isEmptyWorkspaceName: Bool {
        guard case .mutationRejected(.emptyWorkspaceName) = self else {
            return false
        }

        return true
    }
}
