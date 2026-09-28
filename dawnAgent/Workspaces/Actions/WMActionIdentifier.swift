import PaEventKit

public enum WMActionIdentifier {
    case hideApp(WorkspaceApplication) // Hide all windows of target app
    case openApp(WorkspaceApplication) // Open or Show target app
    case closeApp(WorkspaceApplication) // Close an target app
    case resetWindows // Hide and reset windows of all apps

    var action: WMAction {
        return switch self {
        case let .hideApp(app): WMHideAppAction(app)
        case let .openApp(app): WMOpenAppAction(app)
        case let .closeApp(app): WMCloseAppAction(app)
        case .resetWindows: WMResetWindowsAction()
        }
    }
}
