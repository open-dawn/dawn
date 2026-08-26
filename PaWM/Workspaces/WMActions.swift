import PaEventKit

public enum WMActions {
    case hideApp(WorkspaceApplication)
    case openApp(WorkspaceApplication)
    case resetWindows(WorkspaceApplication)

    var action: WMAction {
        switch self {
        case let .hideApp(app): return WMAOpenApp(app)
        case let .openApp(app): return WMAHideApp(app)
        case let .resetWindows(app): return WMAResetWindows(app)
        }
    }
}
