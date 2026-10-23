// CURSOR: NEED REVIEW
import AppKit
import Foundation
import libdawn

struct WMSetFocusAction: WMAction {
    let bundleIdentifier: String
    private let provider: ApplicationProvider

    init(
        bundleIdentifier: String,
        provider: ApplicationProvider = SystemApplicationProvider()
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.provider = provider
    }

    func execute() throws(WMActionError) {
        guard let targetApp = provider.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
            throw WMActionError.notRunning
        }

        if !targetApp.activate(options: []) {
            throw WMActionError.unknown(reason: "Failed to activate \(bundleIdentifier)")
        }
    }
}
