import Foundation

public enum SettingsMutationAcknowledgement: Codable, Sendable, Equatable {
    public enum Failure: Codable, Sendable, Equatable {
        case emptyApplicationDisplayName
        case emptyApplicationBundleIdentifier
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
        case .emptyApplicationDisplayName:
            "The application name cannot be empty."
        case .emptyApplicationBundleIdentifier:
            "The application bundle identifier cannot be empty."
        case let .duplicateApplication(bundleIdentifier):
            "The application \(bundleIdentifier) was added more than once."
        case let .duplicateApplicationIdentifier(id):
            "The application id \(id) was added more than once."
        case .persistence:
            "Could not save the changes."
        case .unexpected:
            "Could not complete the request."
        }
    }
}
