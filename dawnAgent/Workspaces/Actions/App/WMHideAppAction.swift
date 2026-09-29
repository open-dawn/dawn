import AppKit
import Foundation
import libdawn

struct WMHideAppAction: WMAppAction {
    private(set) var app: WorkspaceApplication
    private let provider: ApplicationProvider

    func execute() async throws(WMActionError) {
        guard let targetApp = provider.runningApplications(withBundleIdentifier: app.bundleIdentifier).first else {
            throw WMActionError.notRunning
        }

        targetApp.activate(options: [])
        if !targetApp.hide() {
            throw WMActionError.noGUItoShow
        }
    }

    init(_ app: WorkspaceApplication, provider: ApplicationProvider = SystemApplicationProvider()) {
        self.app = app
        self.provider = provider
    }
}
