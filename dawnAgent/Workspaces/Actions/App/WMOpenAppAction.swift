import AppKit
import Foundation
import dawnLogging
import libdawn

struct WMOpenAppAction: WMAppAction {
    private(set) var app: WorkspaceApplication
    private(set) var workspace: WorkspaceOpener
    private let provider: ApplicationProvider

    func execute() async throws(WMActionError) {
        _ = try await open()
    }

    func open() async throws(WMActionError) -> pid_t {
        if shouldRestoreRunningApplication,
           let runningApp = provider.runningApplications(withBundleIdentifier: app.bundleIdentifier).first
        {
            try restore(runningApp)
            return runningApp.processIdentifier
        }

        guard let appUrl: URL = app.applicationURL else {
            #log(
                "Unable to open \(app.bundleIdentifier): missing application URL",
                level: .error,
                category: .general
            )

            throw WMActionError.invalidURL
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.hides = false
        configuration.hidesOthers = false
        configuration.requiresUniversalLinks = false
        configuration.allowsRunningApplicationSubstitution = app.allowsRunningApplicationSubstitution
        configuration.createsNewApplicationInstance = app.createsNewApplicationInstance
        configuration.arguments = app.arguments
        configuration.environment = app.environment
        configuration.promptsUserIfNeeded = app.promptsUserIfNeeded

        do {
            let launchedApp = try await workspace.openRunningApplication(
                at: appUrl,
                configuration: configuration
            )
            return launchedApp.processIdentifier
        } catch {
            let actionError = map(workspaceError: error, filePath: appUrl.path())

            let description = actionError.localizedDescription ?? "Unknown window-management error"

            #log(
                "Failed to open \(app.bundleIdentifier): \(description)",
                level: .error,
                category: .general
            )

            throw actionError
        }
    }

    private var shouldRestoreRunningApplication: Bool {
        app.allowsRunningApplicationSubstitution && !app.createsNewApplicationInstance
    }

    private func restore(_ runningApp: any RunningApplicationControlling) throws(WMActionError) {
        if runningApp.isHidden, !runningApp.unhide() {
            #log(
                "Unable to unhide \(app.bundleIdentifier)",
                level: .error,
                category: .general
            )
            throw WMActionError.noGUItoShow
        }

        runningApp.activate(options: .activateAllWindows)
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

    init(
        app: WorkspaceApplication,
        workspace: WorkspaceOpener = NSWorkspace.shared,
        provider: ApplicationProvider = SystemApplicationProvider()
    ) {
        self.app = app
        self.workspace = workspace
        self.provider = provider
    }
}

protocol WorkspaceOpener {
    @discardableResult
    func openRunningApplication(
        at url: URL,
        configuration: NSWorkspace.OpenConfiguration
    ) async throws -> any RunningApplicationControlling
}

extension NSWorkspace: WorkspaceOpener {
    func openRunningApplication(
        at url: URL,
        configuration: NSWorkspace.OpenConfiguration
    ) async throws -> any RunningApplicationControlling {
        try await openApplication(at: url, configuration: configuration)
    }
}
