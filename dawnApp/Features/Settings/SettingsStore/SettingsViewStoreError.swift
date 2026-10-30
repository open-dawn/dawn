import Foundation
import libdawn

enum SettingsViewStoreError: Error, Equatable, LocalizedError {
    case notConnected
    case noHandler
    case timeout
    case invalidPayload
    case unexpectedResponse(EventKind)
    case mutationRejected(SettingsMutationAcknowledgement.Failure)
    case unknown

    init(_ error: any Error) {
        if let storeError = error as? Self {
            self = storeError
            return
        }

        if let remoteError = error as? EventRemoteError {
            switch remoteError {
            case .notConnected: self = .notConnected
            case .invalidPayload: self = .invalidPayload
            }

            return
        }

        if let askError = error as? EventAskError {
            switch askError {
            case .noHandler: self = .noHandler
            case .timeout: self = .timeout
            }

            return
        }

        self = .unknown
    }

    var errorDescription: String? {
        switch self {
        case .notConnected: "Settings store is not connected."
        case .noHandler: "Settings store cannot handle this request."
        case .timeout: "Settings store did not respond in time."
        case .invalidPayload, .unexpectedResponse: "Settings store returned an invalid response."
        case let .mutationRejected(failure): failure.errorDescription
        case .unknown: "An unexpected error occurred."
        }
    }
}
