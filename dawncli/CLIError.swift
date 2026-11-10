import Foundation

enum CLIError: Error, Equatable, LocalizedError {
    case contextNotFound(UUID)
    case contextIdentifierMismatch(expected: UUID, received: UUID)
    case unreadableFile(String)
    case invalidJSON(String)

    var errorDescription: String? {
        switch self {
        case let .contextNotFound(id):
            "No context with id \(id.uuidString)."
        case let .contextIdentifierMismatch(expected, received):
            "Expected context \(expected.uuidString) but received \(received.uuidString)."
        case let .unreadableFile(path):
            "Could not read \(path)."
        case let .invalidJSON(path):
            "Could not read JSON from \(path)."
        }
    }
}
