import Foundation

enum ViewModelError: Error, LocalizedError, Equatable {
    case invalidSetting
    case invalidAccess
    case loadFailed
    case persistenceFailed
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidSetting: "Invalid setting"
        case .invalidAccess: "Attempt to access invalid position"
        case .loadFailed: "Could not load settings."
        case .persistenceFailed: "Could not save settings."
        case .unknown: "An unexpected error occurred."
        }
    }
}
