//
//  PaSettingsContextStoreError.swift
//  pineapplewm
//
//  Created by Rafael Venetikides on 22/09/26.
//

import PaEventKit
import Foundation

enum PaSettingsContextStoreError: Error, Equatable {
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
}
