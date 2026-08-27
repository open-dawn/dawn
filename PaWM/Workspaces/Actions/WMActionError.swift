enum WMActionError: Error, Equatable {
    case notFound(filePath: String)
    case permissionDenied
    case corruptedFile
    case invalidURL
    case notRunning
    case noGUItoShow
    case unknown(reason: String?)

    var localizedDescription: String {
        switch self {
        case let .notFound(filePath): return "\"\(filePath)\" not found"
        case .permissionDenied: return "Permission denied"
        case .corruptedFile: return "Application corrupted or not signed"
        case .invalidURL: return "Error in URL creation"
        case .notRunning: return "Application is not running"
        case .noGUItoShow: return "Attempt to hide an application without interface"
        case let .unknown(reason): return "Unknown Error (\(reason ?? "nil"))"
        }
    }
}
