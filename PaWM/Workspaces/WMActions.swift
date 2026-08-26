import PaEventKit

public enum WMActions {
    case hideApp(WorkspaceApplication) // Hide all windows of target app
    case openApp(WorkspaceApplication) // Open/Show target app
    case resetWindows // Hide and reset windows of all apps

    var action: WMAction {
        switch self {
        case let .hideApp(app): return WMAOpenApp(app)
        case let .openApp(app): return WMAHideApp(app)
        case .resetWindows: return WMAResetWindows()
        }
    }
}
