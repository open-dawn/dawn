import AppKit
import Foundation
import PaEventKit

struct WMHideAppAction: WMAction {
    private(set) var app: WorkspaceApplication

    func execute() throws(WMActionError) {
        if let targetApp = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier).first {
            targetApp.activate()
            targetApp.hide()
            return
        }

        throw WMActionError.notRunning
    }

    init(_ app: WorkspaceApplication) {
        self.app = app
    }
}