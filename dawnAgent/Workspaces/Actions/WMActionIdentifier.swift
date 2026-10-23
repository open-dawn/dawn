// CURSOR: NEED REVIEW
import libdawn

public enum WMActionIdentifier {
    case hideApp(WorkspaceApplication) // Hide all windows of target app
    case openApp(WorkspaceApplication) // Open or Show target app
    case closeApp(WorkspaceApplication) // Close an target app
    case resetWindows(ActivationPolicy, keep: [WorkspaceApplication]) // Apply activation policy to non-members
    case setFocus(focusModeName: String) // Enable macOS Focus mode if possible
    case terminalCommand(String) // Run a shell command
    case workspaceTransition(WorkspaceContext) // Full enter-workspace transition

    var action: WMAction {
        return switch self {
        case let .hideApp(app): WMHideAppAction(app)
        case let .openApp(app): WMOpenAppAction(app)
        case let .closeApp(app): WMCloseAppAction(app)
        case let .resetWindows(policy, keep):
            WMResetWindowsAction(activationPolicy: policy, keepApplications: keep)
        case let .setFocus(focusModeName): WMSetFocusAction(focusModeName: focusModeName)
        case let .terminalCommand(command): WMTerminalCommandAction(command: command)
        case let .workspaceTransition(context): WMWorkspaceTransitionAction(context: context)
        }
    }
}
