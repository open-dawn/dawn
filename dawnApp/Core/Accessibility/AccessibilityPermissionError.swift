import Foundation
import libdawn

enum AccessibilityPermissionError: Error, Equatable, LocalizedError {
    case unexpectedResponse(EventKind)
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case let .unexpectedResponse(kind):
            "Unexpected accessibility response (\(kind.rawValue))"
        case let .requestFailed(message):
            message
        }
    }

    init(_ error: Error) {
        if let permissionError = error as? AccessibilityPermissionError {
            self = permissionError
        } else {
            self = .requestFailed(error.localizedDescription)
        }
    }
}
