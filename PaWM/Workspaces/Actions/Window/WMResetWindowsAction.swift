import AppKit
import Foundation
import PaEventKit

struct WMResetWindowsAction: WMAction {
    func execute() throws(WMActionError) {
        NSWorkspace.shared.hideOtherApplications()
    }
}
