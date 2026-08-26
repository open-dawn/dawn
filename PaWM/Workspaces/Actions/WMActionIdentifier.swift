import PaEventKit

public enum WMActionIdentifier {
    case hideApp(WorkspaceApplication) // Hide all windows of target app
    case openApp(WorkspaceApplication) // Open or Show target app
    case resetWindows // Hide and reset windows of all apps

    var action: WMAction {
        switch self {
        case let .hideApp(app): return WMHideAppAction(app)
        case let .openApp(app): return WMOpenAppAction(app)
        case .resetWindows: return WMResetWindowsAction()
        }
    }
}
