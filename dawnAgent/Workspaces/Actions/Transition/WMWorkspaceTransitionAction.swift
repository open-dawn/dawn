import AppKit
import dawnLogging
import Foundation
import libdawn

protocol WorkspaceTransitionPerforming {
    func resetWindows(policy: WorkspaceActivationPolicy, keepApplications: [WorkspaceApplication]) async throws
    func openApp(_ app: WorkspaceApplication) async throws -> pid_t
    func waitForWindows(processIdentifier: pid_t) async
    func applyWindowLayout(_ app: WorkspaceApplication, processIdentifier: pid_t?) async throws
    func runTerminalCommand(_ command: String) async throws
}

struct DefaultWorkspaceTransitionPerformer: WorkspaceTransitionPerforming {
    private let provider: ApplicationProvider
    private let workspace: WorkspaceOpener
    private let windows: any AccessibilityWindowServing
    private let trustChecker: any AccessibilityTrustChecking
    private let windowWaitTimeout: Duration
    private let windowPollInterval: Duration

    init(
        provider: ApplicationProvider = SystemApplicationProvider(),
        workspace: WorkspaceOpener = NSWorkspace.shared,
        windows: any AccessibilityWindowServing = SystemAccessibilityWindowService(),
        trustChecker: any AccessibilityTrustChecking = SystemAccessibilityTrustChecker(),
        windowWaitTimeout: Duration = .seconds(3),
        windowPollInterval: Duration = .milliseconds(100)
    ) {
        self.provider = provider
        self.workspace = workspace
        self.windows = windows
        self.trustChecker = trustChecker
        self.windowWaitTimeout = windowWaitTimeout
        self.windowPollInterval = windowPollInterval
    }

    func resetWindows(policy: WorkspaceActivationPolicy, keepApplications: [WorkspaceApplication]) async throws {
        let applied = await AppliedSettings.shared.snapshot()
        try WMResetWindowsAction(
            activationPolicy: SettingsWindowPolicy.activationPolicy(
                policy,
                forceAppsToQuit: applied.forceAppsToQuit
            ),
            keepApplications: keepApplications,
            protectedBundleIdentifiers: SettingsWindowPolicy.protectedBundleIdentifiers(
                extra: applied.protectedApps
            ),
            provider: provider
        ).execute()
    }

    func openApp(_ app: WorkspaceApplication) async throws -> pid_t {
        try await WMOpenAppAction(app: app, workspace: workspace, provider: provider).open()
    }

    func waitForWindows(processIdentifier: pid_t) async {
        let deadline = ContinuousClock.now + windowWaitTimeout

        while ContinuousClock.now < deadline {
            if hasWindows(forProcessIdentifier: processIdentifier) {
                return
            }

            try? await Task.sleep(for: windowPollInterval)
        }

        #log(
            "Timed out waiting for windows of pid \(processIdentifier) after \(windowWaitTimeout)",
            level: .warning,
            category: .general
        )
    }

    func applyWindowLayout(_ app: WorkspaceApplication, processIdentifier: pid_t?) async throws {
        try await WMWindowLayoutAction(
            app: app,
            processIdentifier: processIdentifier,
            provider: provider,
            windows: windows,
            trustChecker: trustChecker
        ).execute()
    }

    func runTerminalCommand(_ command: String) async throws {
        try await WMTerminalCommandAction(command: command).execute()
    }

    private func hasWindows(forProcessIdentifier processIdentifier: pid_t) -> Bool {
        do {
            return try !windows.windows(forProcessID: processIdentifier).isEmpty
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
            let processIdentifier: pid_t
            do {
                processIdentifier = try await performer.openApp(app)
            } catch {
                #log(
                    "Error opening app \(app.bundleIdentifier) (\(error))",
                    level: .error,
                    category: .general
                )
                continue
            }

            guard canApplyLayout else { continue }

            await performer.waitForWindows(processIdentifier: processIdentifier)
            await applyWindowLayout(app, processIdentifier: processIdentifier)
        }

        if canApplyLayout {
            for app in applications where !openedIDs.contains(app.id) {
                await applyWindowLayout(app, processIdentifier: nil)
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

    private func applyWindowLayout(_ app: WorkspaceApplication, processIdentifier: pid_t?) async {
        do {
            try await performer.applyWindowLayout(app, processIdentifier: processIdentifier)
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
                app.createsNewApplicationInstance ||
                    provider
                    .runningApplications(
                        withBundleIdentifier: app.bundleIdentifier
                    )
                    .isEmpty
            }
        }
    }
}
