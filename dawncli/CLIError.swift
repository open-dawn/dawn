import Foundation

enum CLIError: Error, Equatable, LocalizedError {
    case contextNotFound(UUID)
    case contextIdentifierMismatch(expected: UUID, received: UUID)
    case applicationNotFound(String)
    case protectedAppExists(String)
    case protectedAppMissing(String)
    case unreadableFile(String)
    case invalidJSON(String)

    var errorDescription: String? {
        switch self {
        case let .contextNotFound(id):
            "No context with id \(id.uuidString)."
        case let .contextIdentifierMismatch(expected, received):
            "Expected context \(expected.uuidString) but received \(received.uuidString)."
        case let .applicationNotFound(bundleIdentifier):
            "No installed application with bundle identifier \(bundleIdentifier)."
        case let .protectedAppExists(bundleIdentifier):
            "\(bundleIdentifier) is already protected."
        case let .protectedAppMissing(bundleIdentifier):
            "\(bundleIdentifier) is not protected."
        case let .unreadableFile(path):
            "Could not read \(path)."
        case let .invalidJSON(path):
            "Could not read JSON from \(path)."
        }
    }
}
