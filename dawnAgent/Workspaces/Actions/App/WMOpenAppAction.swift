import AppKit
import Foundation
import libdawn

struct WMOpenAppAction: WMAppAction {
    private(set) var app: WorkspaceApplication
    private(set) var workspace: WorkspaceOpener

    func execute() async throws(WMActionError) {
        guard let appUrl: URL = app.applicationURL else { throw WMActionError.invalidURL }

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
            try await workspace.openApplication(at: appUrl, configuration: configuration)
        } catch {
            throw map(workspaceError: error, filePath: appUrl.path())
        }
    }

    private func map(workspaceError error: Error, filePath: String) -> WMActionError {
        let nsError = error as NSError
        guard nsError.domain == NSCocoaErrorDomain else {
            return .unknown(reason: error.localizedDescription)
        }

        return switch nsError.code {
        case NSFileReadNoPermissionError: .permissionDenied
        case NSFileReadCorruptFileError: .corruptedFile
        case NSFileReadNoSuchFileError: .notFound(filePath: filePath)
        default: .unknown(reason: error.localizedDescription)
        }
    }

    init(_ app: WorkspaceApplication, workspace: WorkspaceOpener = NSWorkspace.shared) {
        self.app = app
        self.workspace = workspace
    }
}

protocol WorkspaceOpener {
    @discardableResult
    func openApplication(at url: URL, configuration: NSWorkspace.OpenConfiguration) async throws -> NSRunningApplication
}

extension NSWorkspace: WorkspaceOpener {}
