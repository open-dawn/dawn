import AppKit
import Foundation
import PaEventKit

struct WMAResetWindows: WMAction {
    private(set) var app: WorkspaceApplication

    func execute() throws(WMActionError) {
        NSWorkspace.shared.hideOtherApplications()
    }

    init() {
        app = WorkspaceApplication(bundleIdentifier: "",
                                   displayName: "",
                                   applicationURL: nil,
                                   createNewInstance: false)
    }
}
