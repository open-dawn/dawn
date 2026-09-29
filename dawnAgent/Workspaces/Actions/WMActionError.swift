import Foundation

enum WMActionError: LocalizedError, Equatable {
    case notFound(filePath: String)
    case permissionDenied
    case corruptedFile
    case invalidURL
    case notRunning
    case noGUItoShow
    case unknown(reason: String?)

    var localizedDescription: String? {
        return switch self {
        case let .notFound(filePath): String(localized: "\"\(filePath)\" not found")
        case .permissionDenied: String(localized: "Permission denied")
        case .corruptedFile: String(localized: "Application corrupted or not signed")
        case .invalidURL: String(localized: "Error in URL creation")
        case .notRunning: String(localized: "Application is not running")
        case .noGUItoShow: String(localized: "Attempt to hide an application without interface")
        case let .unknown(reason): String(localized: "Unknown Error (\(reason ?? "nil"))")
        }
    }
}
