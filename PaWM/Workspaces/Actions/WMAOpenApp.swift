import AppKit
import Foundation
import PaEventKit

struct WMAOpenApp: WMAction {
    private(set) var app: WorkspaceApplication

    func execute() async throws(WMActionError) {
        guard let appUrl: URL = app.applicationURL else { throw WMActionError.invalidURL }
        guard FileManager.default.fileExists(atPath: appUrl.path()) else {
            throw WMActionError.notFound(filePath: appUrl.path())
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = false // Future setting
        configuration.hides = false
        configuration.hidesOthers = false
        configuration.promptsUserIfNeeded = false // Future setting
        configuration.appleEvent = nil
        // configuration.arguments = []
        // configuration.environment = [:]
        // configuration.architecture = x86_64

        do {
            try await NSWorkspace.shared.openApplication(at: appUrl, configuration: configuration)
        } catch {
            throw map(workspaceError: error)
        }
    }

    private func map(workspaceError error: Error) -> WMActionError {
        let nsError = error as NSError

        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case NSFileReadNoPermissionError: return .permissionDenied
            case NSFileReadCorruptFileError: return .corruptedFile
            default: break
            }
        }

        return .unknown(reason: error.localizedDescription)
    }

    init(_ app: WorkspaceApplication) {
        self.app = app
    }
}
