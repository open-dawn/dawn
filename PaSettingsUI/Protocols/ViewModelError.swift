import Foundation
enum ViewModelError: Error, LocalizedError, Equatable {
    case invalidSetting
    case invalidAccess
    case loadFailed
    case persistenceFailed
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidSetting: return "Invalid setting"
        case .invalidAccess: return "Attempt to access invalid position"
        default: return "unknown error"
        }
    }
}
