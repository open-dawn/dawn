import dawnLogging
import Foundation
import libdawn

protocol WorkspaceTransitionPerforming {
    func resetWindows(policy: WorkspaceActivationPolicy, keepApplications: [WorkspaceApplication]) async throws
    func openApp(_ app: WorkspaceApplication) async throws
    func waitForWindows(bundleIdentifier: String) async
    func applyWindowLayout(_ app: WorkspaceApplication) async throws
    func runTerminalCommand(_ command: String) async throws
}

struct DefaultWorkspaceTransitionPerformer: WorkspaceTransitionPerforming {
    private let provider: ApplicationProvider
    private let windows: any AccessibilityWindowServing
    private let windowWaitTimeout: Duration
    private let windowPollInterval: Duration

    init(
        provider: ApplicationProvider = SystemApplicationProvider(),
        windows: any AccessibilityWindowServing = SystemAccessibilityWindowService(),
        windowWaitTimeout: Duration = .seconds(3),
        windowPollInterval: Duration = .milliseconds(100)
    ) {
        self.provider = provider
        self.windows = windows
        self.windowWaitTimeout = windowWaitTimeout
        self.windowPollInterval = windowPollInterval
    }

    func resetWindows(policy: WorkspaceActivationPolicy, keepApplications: [WorkspaceApplication]) async throws {
        try WMResetWindowsAction(activationPolicy: policy, keepApplications: keepApplications).execute()
    }

    func openApp(_ app: WorkspaceApplication) async throws {
        try await WMOpenAppAction(app: app).execute()
    }

    func waitForWindows(bundleIdentifier: String) async {
        let deadline = ContinuousClock.now + windowWaitTimeout

        while ContinuousClock.now < deadline {
            if hasWindows(forBundleIdentifier: bundleIdentifier) {
                return
            }

            try? await Task.sleep(for: windowPollInterval)
        }

        #log(
            "Timed out waiting for windows of \(bundleIdentifier) after \(windowWaitTimeout)",
            level: .warning,
            category: .general
        )
    }

    func applyWindowLayout(_ app: WorkspaceApplication) async throws {
        try await WMWindowLayoutAction(app: app).execute()
    }

    func runTerminalCommand(_ command: String) async throws {
        try await WMTerminalCommandAction(command: command).execute()
    }

    private func hasWindows(forBundleIdentifier bundleIdentifier: String) -> Bool {
        guard let runningApp = provider.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
            return false
        }

        do {
            return try !windows.windows(forProcessID: runningApp.processIdentifier).isEmpty
        } catch {
            return false
        }
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
        let canApplyLayout = trustChecker.isProcessTrusted()

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

        let appsToOpen = applicationsToOpen(applications, policy: transition.activationPolicy)
        let openedIDs = Set(appsToOpen.map(\.id))

        for app in appsToOpen {
            do {
                try await performer.openApp(app)
            } catch {
                #log(
                    "Error opening app \(app.bundleIdentifier) (\(error))",
                    level: .error,
                    category: .general
                )
                continue
            }

            guard canApplyLayout else { continue }

            await performer.waitForWindows(bundleIdentifier: app.bundleIdentifier)
            await applyWindowLayout(app)
        }

        if canApplyLayout {
            for app in applications where !openedIDs.contains(app.id) {
                await applyWindowLayout(app)
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

    private func applyWindowLayout(_ app: WorkspaceApplication) async {
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
