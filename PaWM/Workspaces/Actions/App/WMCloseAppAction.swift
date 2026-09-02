import AppKit
import Foundation
import PaEventKit

/// In future create a NSRunningApplicationMock to fake .terminate()
struct WMCloseAppAction: WMAppAction {
    private(set) var app: WorkspaceApplication
    private let provider: ApplicationProvider

    func execute() throws(WMActionError) {
        if let targetApp = provider.runningApplications(withBundleIdentifier: app.bundleIdentifier).first {
            targetApp.activate()
            if type(of: provider) == SystemApplicationProvider.self, !targetApp.terminate() {
                throw WMActionError.permissionDenied
            }

            return
        }

        throw WMActionError.notRunning
    }

    init(_ app: WorkspaceApplication, provider: ApplicationProvider = SystemApplicationProvider()) {
        self.app = app
        self.provider = provider
    }
}
