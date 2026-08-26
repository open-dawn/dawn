import AppKit
import Foundation
import PaEventKit

struct WMOpenAppAction: WMAction {
    private(set) var app: WorkspaceApplication
    private(set) var workspace: WorkspaceOpener
    private(set) var fileManager: FileChecker

    func execute() async throws(WMActionError) {
        guard let appUrl: URL = app.applicationURL else { throw WMActionError.invalidURL }
        guard fileManager.fileExists(atPath: appUrl.path()) else {
            throw WMActionError.notFound(filePath: appUrl.path())
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = app.createNewInstance
        configuration.hides = false
        configuration.hidesOthers = false
        configuration.promptsUserIfNeeded = false // Future setting
        // configuration.appleEvent = nil
        // configuration.arguments = []
        // configuration.environment = [:]
        // configuration.architecture = x86_64

        do {
            _ = try await workspace.openApplication(at: appUrl, configuration: configuration)
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

    init(_ app: WorkspaceApplication,
         workspace: WorkspaceOpener = NSWorkspace.shared,
         fileManager: FileChecker = FileManager.default)
    {
        self.app = app
        self.workspace = workspace
        self.fileManager = fileManager
    }
}

// MARK: - Protocols to testing with mock

protocol WorkspaceOpener {
    func openApplication(at url: URL, configuration: NSWorkspace.OpenConfiguration) async throws -> NSRunningApplication
}

protocol FileChecker {
    func fileExists(atPath path: String) -> Bool
}

extension NSWorkspace: WorkspaceOpener {}
extension FileManager: FileChecker {}
