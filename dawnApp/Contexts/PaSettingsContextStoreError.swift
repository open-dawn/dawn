//
//  PaSettingsContextStoreError.swift
//  pineapplewm
//
//  Created by Rafael Venetikides on 22/09/26.
//

import PaEventKit
import Foundation

enum PaSettingsContextStoreError: Error, Equatable, LocalizedError {
    case notConnected
    case noHandler
    case timeout
    case invalidPayload
    case unexpectedResponse(PaEventKind)
    case mutationRejected(PaContextMutationAcknowledgement.Failure)
    case unknown

    case contextIdentifierMismatch(expected: UUID, received: UUID)

    init(_ error: any Error) {
        if let storeError = error as? Self {
            self = storeError
            return
        }

        if let remoteError = error as? PaEventRemoteError {
            switch remoteError {
            case .notConnected:
                self = .notConnected

            case .invalidPayload:
                self = .invalidPayload
            }

            return
        }

        if let askError = error as? PaEventAskError {
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
        case .contextIdentifierMismatch:
            "Workspace manager returned the wrong context."
        }
    }
}
