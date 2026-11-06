import Foundation
import libdawn

enum ApplicationSelectionError: Error, LocalizedError, Equatable {
    case invalidApplication
    case missingBundleIdentifier
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidApplication:
            "The selected item is not a valid application."
        case .missingBundleIdentifier:
            "The selected application has no bundle identifier."
        case .unknown:
            "The application could not be selected"
        }
    }
}

extension WorkspaceApplication {
    static func imported(from applicationURL: URL) throws -> WorkspaceApplication {
        guard let bundle = Bundle(url: applicationURL) else {
            throw ApplicationSelectionError.invalidApplication
        }

        guard let bundleIdentifier = bundle.bundleIdentifier else {
            throw ApplicationSelectionError.missingBundleIdentifier
        }

        let displayName =
            bundle.object(
                forInfoDictionaryKey: "CFBundleDisplayName"
            ) as? String ?? bundle.object(
                forInfoDictionaryKey: "CFBundleName"
            ) as? String ?? applicationURL.deletingPathExtension().lastPathComponent

        return WorkspaceApplication(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            applicationURL: applicationURL
        )
    }
}
