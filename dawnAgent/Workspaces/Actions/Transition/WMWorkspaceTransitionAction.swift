import dawnLogging
import Foundation
import libdawn

protocol WorkspaceTransitionPerforming {
    func resetWindows(policy: ActivationPolicy, keepApplications: [WorkspaceApplication]) async throws
    func openApp(_ app: WorkspaceApplication) async throws
    func setFocus(focusModeName: String) async throws
    func runTerminalCommand(_ command: String) async throws
}

struct DefaultWorkspaceTransitionPerformer: WorkspaceTransitionPerforming {
    func resetWindows(policy: ActivationPolicy, keepApplications: [WorkspaceApplication]) async throws {
        try WMResetWindowsAction(activationPolicy: policy, keepApplications: keepApplications).execute()
    }

    func openApp(_ app: WorkspaceApplication) async throws {
        try await WMOpenAppAction(app: app).execute()
    }

    func setFocus(focusModeName: String) async throws {
        try WMSetFocusAction(focusModeName: focusModeName).execute()
    }

    func runTerminalCommand(_ command: String) async throws {
        try WMTerminalCommandAction(command: command).execute()
    }
}

struct WMWorkspaceTransitionAction: WMAction {
    let context: WorkspaceContext
    private let provider: ApplicationProvider
    private let performer: WorkspaceTransitionPerforming

    init(
        context: WorkspaceContext,
        provider: ApplicationProvider = SystemApplicationProvider(),
        performer: WorkspaceTransitionPerforming = DefaultWorkspaceTransitionPerformer()
    ) {
        self.context = context
        self.provider = provider
        self.performer = performer
    }

    func execute() async throws(WMActionError) {
        let transition = context.transition
        let applications = context.applications

        do {
            try await performer.resetWindows(
                policy: transition.activationPolicy,
                keepApplications: applications
            )
        } catch {
            let policy = transition.activationPolicy.rawValue
            #log(
                "Error applying activation policy \(policy): \(error.localizedDescription)",
                level: .error,
                category: .general
            )
        }

        for app in applications {
            do {
                try await performer.openApp(app)
            } catch {
                #log(
                    "Error opening app \(app.bundleIdentifier) (\(error))",
                    level: .error,
                    category: .general
                )
            }
        }

        if let focusModeName = transition.setFocus, !focusModeName.isEmpty {
            do {
                try await performer.setFocus(focusModeName: focusModeName)
            } catch {
                #log(
                    "Unable to enable Focus mode \(focusModeName): \(error.localizedDescription)",
                    level: .warning,
                    category: .general
                )
            }
        }

        if let command = transition.terminalCommand, !command.isEmpty {
            do {
                try await performer.runTerminalCommand(command)
            } catch {
                #log(
                    "Unable to run terminal command: \(error.localizedDescription)",
                    level: .warning,
                    category: .general
                )
            }
        }
    }
}
