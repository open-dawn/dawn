import AppKit
import Foundation
import PaEventKit

struct WMCloseAppAction: WMAppAction {
    private(set) var app: WorkspaceApplication
    private let provider: ApplicationProvider

    func execute() throws(WMActionError) {
        // In future create a NSRunningApplicationMock to fake .terminate()
        guard let targetApp = provider.runningApplications(withBundleIdentifier: app.bundleIdentifier).first else {
            throw WMActionError.notRunning
        }

        targetApp.activate(options: [])
        if !targetApp.terminate() {
            throw WMActionError.permissionDenied
        }
    }

    init(_ app: WorkspaceApplication, provider: ApplicationProvider = SystemApplicationProvider()) {
        self.app = app
        self.provider = provider
    }
}
