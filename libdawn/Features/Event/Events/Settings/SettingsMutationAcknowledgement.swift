import Foundation

public enum SettingsMutationAcknowledgement: Codable, Sendable, Equatable {
    public enum Failure: Codable, Sendable, Equatable {
        case emptyApplicationName
        case unexpectedApplicationName(name: String)
        case duplicateApplication(bundleIdentifier: String)
        case duplicateApplicationIdentifier(id: UUID)

        case persistence
        case unexpected
    }

    case success
    case failure(failure: Failure)
}

extension SettingsMutationAcknowledgement.Failure: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .emptyApplicationName: "The application name can not be empty"
        case let .duplicateApplicationIdentifier(id): "The application id \(id) was added more than once."
        case let .duplicateApplication(bundleIdentifier):
            "The application \(bundleIdentifier) was added more than once."
        case let .unexpectedApplicationName(name): "\(name) is not a valid name"
        case .persistence: "Could not save the changes."
        case .unexpected: "Could not complete the request."
        }
    }
}
