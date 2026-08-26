import AppKit
import Foundation
import PaEventKit

struct WMAHideApp: WMAction {
    private(set) var app: WorkspaceApplication

    func execute() throws(WMActionError) {}

    init(_ app: WorkspaceApplication) {
        self.app = app
    }
}
