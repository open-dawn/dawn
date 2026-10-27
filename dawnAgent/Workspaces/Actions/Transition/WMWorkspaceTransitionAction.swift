import dawnLogging
import Foundation
import libdawn

protocol WorkspaceTransitionPerforming {
    func resetWindows(policy: WorkspaceActivationPolicy, keepApplications: [WorkspaceApplication]) async throws
    func openApp(_ app: WorkspaceApplication) async throws
    func applyWindowLayout(_ app: WorkspaceApplication) async throws
    func runTerminalCommand(_ command: String) async throws
}

struct DefaultWorkspaceTransitionPerformer: WorkspaceTransitionPerforming {
    func resetWindows(policy: WorkspaceActivationPolicy, keepApplications: [WorkspaceApplication]) async throws {
        try WMResetWindowsAction(activationPolicy: policy, keepApplications: keepApplications).execute()
    }

    func openApp(_ app: WorkspaceApplication) async throws {
        try await WMOpenAppAction(app: app).execute()
    }

    func applyWindowLayout(_ app: WorkspaceApplication) async throws {
        try await WMWindowLayoutAction(app: app).execute()
    }

    func runTerminalCommand(_ command: String) async throws {
        try await WMTerminalCommandAction(command: command).execute()
    }
}

struct WMWorkspaceTransitionAction: WMAction {
    let context: WorkspaceContext
    private let provider: ApplicationProvider
    private let performer: WorkspaceTransitionPerforming
    private let trustChecker: any AccessibilityTrustChecking

    init(
        context: WorkspaceContext,
        provider: ApplicationProvider = SystemApplicationProvider(),
        performer: WorkspaceTransitionPerforming = DefaultWorkspaceTransitionPerformer(),
        trustChecker: any AccessibilityTrustChecking = SystemAccessibilityTrustChecker()
    ) {
        self.context = context
        self.provider = provider
        self.performer = performer
        self.trustChecker = trustChecker
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

        for app in applicationsToOpen(applications, policy: transition.activationPolicy) {
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

        if trustChecker.isProcessTrusted() {
            for app in applications {
                do {
                    try await performer.applyWindowLayout(app)
                } catch {
                    #log(
                        "Error applying window layout for \(app.bundleIdentifier) (\(error))",
                        level: .error,
                        category: .general
                    )
                }
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

    private func applicationsToOpen(
        _ applications: [WorkspaceApplication],
        policy: WorkspaceActivationPolicy
    ) -> [WorkspaceApplication] {
        switch policy {
        case .hide, .close:
            return applications
        case .merge:
            return applications.filter { app in
                provider.runningApplications(withBundleIdentifier: app.bundleIdentifier).isEmpty
            }
        }
    }
}
