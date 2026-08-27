import AppKit
import Foundation
import PaEventKit

struct WMHideAppAction: WMAction {
    private(set) var app: WorkspaceApplication
    private let provider: ApplicationProvider

    func execute() async throws(WMActionError) {
        if let targetApp = provider.runningApplications(withBundleIdentifier: app.bundleIdentifier).first {
            targetApp.activate()
            targetApp.hide()
            return
        }

        throw WMActionError.notRunning
    }

    init(_ app: WorkspaceApplication, provider: ApplicationProvider = SystemApplicationProvider()) {
        self.app = app
        self.provider = provider
    }
}
