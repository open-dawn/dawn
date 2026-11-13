import Foundation
import libdawn

enum AgentError: Error, Equatable, LocalizedError {
    case notConnected
    case noHandler
    case timeout
    case invalidPayload
    case unexpectedResponse(EventKind)
    case unknown

    init(_ error: any Error) {
        if let agentError = error as? Self {
            self = agentError
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
        case .notConnected: "dawnAgent is not reachable."
        case .noHandler: "dawnAgent cannot handle that request."
        case .timeout: "dawnAgent did not respond in time."
        case .invalidPayload, .unexpectedResponse: "dawnAgent returned an invalid response."
        case .unknown: "An unexpected error occurred."
        }
    }
}
