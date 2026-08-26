import AppKit
import Foundation
import PaEventKit

struct WMCloseAppAction: WMAction {
    private(set) var app: WorkspaceApplication

    func execute() throws(WMActionError) {
        if let targetApp = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier).first {
            targetApp.activate()
            targetApp.terminate()
            return
        }

        throw WMActionError.notRunning
    }

    init(_ app: WorkspaceApplication) {
        self.app = app
    }
}