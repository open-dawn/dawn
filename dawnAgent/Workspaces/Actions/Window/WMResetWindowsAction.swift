import AppKit
import Foundation
import libdawn

struct WMResetWindowsAction: WMAction {
    let workspace: GlobalWorkspaceProvider

    init(workspace: GlobalWorkspaceProvider = NSWorkspace.shared) {
        self.workspace = workspace
    }

    func execute() throws(WMActionError) {
        workspace.hideOtherApplications()
    }
}

protocol GlobalWorkspaceProvider {
    func hideOtherApplications()
}

extension NSWorkspace: GlobalWorkspaceProvider {}
