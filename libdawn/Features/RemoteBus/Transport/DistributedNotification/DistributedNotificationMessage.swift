import Foundation

enum DistributedNotificationMessage {
    enum Operation: String {
        case handshake
        case handshakeResponse
        case publish
        case subscribe
        case ask
        case askResponse
        case deliver
        case close
        case disconnect
    }

    enum Failure: String {
        case notConnected
        case invalidPayload
        case noHandler
        case timeout
        case unknown

        init(error: Error) {
            switch error {
            case EventRemoteError.notConnected:
                self = .notConnected
            case EventRemoteError.invalidPayload:
                self = .invalidPayload
            case EventAskError.noHandler:
                self = .noHandler
            case EventAskError.timeout:
                self = .timeout
            default:
                self = .unknown
            }
        }

        var error: any Error {
            switch self {
            case .notConnected, .unknown:
                EventRemoteError.notConnected
            case .invalidPayload:
                EventRemoteError.invalidPayload
            case .noHandler:
                EventAskError.noHandler
            case .timeout:
                EventAskError.timeout
            }
        }
    }

    static let clientIDKey = "clientID"
    static let operationKey = "operation"
    static let requestIDKey = "requestID"
    static let payloadKey = "payload"
    static let successKey = "success"
    static let failureKey = "failure"
    static let includeAllKey = "includeAll"
    static let kindsKey = "kinds"

    static func requestName(serviceName: String) -> Notification.Name {
        Notification.Name("\(serviceName).request")
    }

    static func responseName(serviceName: String, clientID: String) -> Notification.Name {
        Notification.Name("\(serviceName).client.\(clientID)")
    }
}
