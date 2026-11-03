@testable import dawnAgent
import Foundation
import libdawn
import Testing

@Suite("WMWorkspaceTransitionAction Testing")
struct WMWorkspaceTransitionActionTests {
    @Test("hide policy opens then layouts each app before terminal")
    func hideOpensAllThenTerminal() async throws {
        let safari = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            applicationURL: URL(fileURLWithPath: "/Applications/Safari.app")
        )
        let notes = WorkspaceApplication(
            bundleIdentifier: "com.apple.Notes",
            displayName: "Notes",
            applicationURL: URL(fileURLWithPath: "/Applications/Notes.app")
        )
        let context = WorkspaceContext(
            name: "Work",
            symbol: "briefcase",
            applications: [safari, notes],
            transition: WorkspaceTransition(
                activationPolicy: .hide,
                terminalCommand: "echo dawn"
            )
        )

        let performer = FakeWorkspaceTransitionPerformer()
        let provider = FakeAppProvider()
        let trust = FakeAccessibilityTrustChecker()
        trust.isTrusted = true
        let action = WMWorkspaceTransitionAction(
            context: context,
            provider: provider,
            performer: performer,
            trustChecker: trust
        )

        try await action.execute()

        #expect(performer.resetPolicies == [.hide])
        #expect(performer.openedApps.map(\.bundleIdentifier) == ["com.apple.Safari", "com.apple.Notes"])
        #expect(performer.laidOutApps.map(\.bundleIdentifier) == ["com.apple.Safari", "com.apple.Notes"])
        #expect(performer.terminalCommands == ["echo dawn"])
        #expect(
            performer.steps == [
                .open("com.apple.Safari", 1),
                .wait(1),
                .layout("com.apple.Safari", 1),
                .open("com.apple.Notes", 2),
                .wait(2),
                .layout("com.apple.Notes", 2),
            ]
        )
    }

    @Test("merge policy only opens missing apps but layouts every member")
    func mergeOpensMissingOnly() async throws {
        let safari = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            applicationURL: URL(fileURLWithPath: "/Applications/Safari.app")
        )
        let notes = WorkspaceApplication(
            bundleIdentifier: "com.apple.Notes",
            displayName: "Notes",
            applicationURL: URL(fileURLWithPath: "/Applications/Notes.app")
        )
        let context = WorkspaceContext(
            name: "Merge",
            symbol: "square.on.square",
            applications: [safari, notes],
            transition: WorkspaceTransition(activationPolicy: .merge)
        )

        let runningSafari = FakeRunningApp(bundleIdentifier: "com.apple.Safari")
        let provider = FakeAppProvider()
        provider.appsByBundleIdentifier = ["com.apple.Safari": [runningSafari]]

        let performer = FakeWorkspaceTransitionPerformer()
        let trust = FakeAccessibilityTrustChecker()
        trust.isTrusted = true
        let action = WMWorkspaceTransitionAction(
            context: context,
            provider: provider,
            performer: performer,
            trustChecker: trust
        )

        try await action.execute()

        #expect(performer.resetPolicies == [.merge])
        #expect(performer.openedApps.map(\.bundleIdentifier) == ["com.apple.Notes"])
        #expect(performer.laidOutApps.map(\.bundleIdentifier) == ["com.apple.Notes", "com.apple.Safari"])
        #expect(performer.terminalCommands.isEmpty)
        #expect(
            performer.steps == [
                .open("com.apple.Notes", 1),
                .wait(1),
                .layout("com.apple.Notes", 1),
                .layout("com.apple.Safari", nil),
            ]
        )
    }

    @Test("merge still opens running apps that create a new instance")
    func mergeOpensNewInstanceAppsEvenWhenRunning() async throws {
        let terminal = WorkspaceApplication(
            bundleIdentifier: "com.apple.Terminal",
            displayName: "Terminal",
            applicationURL: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"),
            createsNewApplicationInstance: true
        )
        let notes = WorkspaceApplication(
            bundleIdentifier: "com.apple.Notes",
            displayName: "Notes",
            applicationURL: URL(fileURLWithPath: "/Applications/Notes.app")
        )
        let context = WorkspaceContext(
            name: "MergeNewInstance",
            symbol: "square.on.square",
            applications: [terminal, notes],
            transition: WorkspaceTransition(activationPolicy: .merge)
        )

        let runningTerminal = FakeRunningApp(bundleIdentifier: "com.apple.Terminal")
        let runningNotes = FakeRunningApp(bundleIdentifier: "com.apple.Notes")
        let provider = FakeAppProvider()
        provider.appsByBundleIdentifier = [
            "com.apple.Terminal": [runningTerminal],
            "com.apple.Notes": [runningNotes],
        ]

        let performer = FakeWorkspaceTransitionPerformer()
        let trust = FakeAccessibilityTrustChecker()
        trust.isTrusted = true
        let action = WMWorkspaceTransitionAction(
            context: context,
            provider: provider,
            performer: performer,
            trustChecker: trust
        )

        try await action.execute()

        #expect(performer.resetPolicies == [.merge])
        #expect(performer.openedApps.map(\.bundleIdentifier) == ["com.apple.Terminal"])
        #expect(performer.laidOutApps.map(\.bundleIdentifier) == ["com.apple.Terminal", "com.apple.Notes"])
        #expect(
            performer.steps == [
                .open("com.apple.Terminal", 1),
                .wait(1),
                .layout("com.apple.Terminal", 1),
                .layout("com.apple.Notes", nil),
            ]
        )
    }

    @Test("new instance wait and layout target the launched PID, not an older process")
    func newInstanceUsesLaunchedProcessIdentifier() async throws {
        let terminal = WorkspaceApplication(
            bundleIdentifier: "com.apple.Terminal",
            displayName: "Terminal",
            applicationURL: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"),
            createsNewApplicationInstance: true
        )
        let context = WorkspaceContext(
            name: "NewInstancePID",
            symbol: "terminal",
            applications: [terminal],
            transition: WorkspaceTransition(activationPolicy: .hide)
        )

        let existing = FakeRunningApp(bundleIdentifier: terminal.bundleIdentifier, processIdentifier: 100)
        let launched = FakeRunningApp(bundleIdentifier: terminal.bundleIdentifier, processIdentifier: 200)

        let provider = FakeAppProvider()
        provider.appsByBundleIdentifier = [terminal.bundleIdentifier: [existing]]

        let workspace = FakeWorkspace()
        workspace.applicationToReturn = launched

        let windows = FakeAccessibilityWindowService()
        windows.windowsByPID[100] = [
            AccessibilityWindow(processID: 100, title: "Old", element: FakeAccessibilityElement()),
        ]
        windows.windowsByPID[200] = [
            AccessibilityWindow(processID: 200, title: "New", element: FakeAccessibilityElement()),
        ]

        let trust = FakeAccessibilityTrustChecker()
        trust.isTrusted = true

        let performer = DefaultWorkspaceTransitionPerformer(
            provider: provider,
            workspace: workspace,
            windows: windows,
            trustChecker: trust,
            windowWaitTimeout: .milliseconds(50),
            windowPollInterval: .milliseconds(10)
        )
        let action = WMWorkspaceTransitionAction(
            context: context,
            provider: provider,
            performer: performer,
            trustChecker: trust
        )

        try await action.execute()

        #expect(workspace.didCallOpenApplication)
        #expect(Set(windows.requestedProcessIDs) == Set([pid_t(200)]))
        #expect(windows.raised.map(\.processID) == [200])
    }

    @Test("skips window layout when Accessibility is not trusted")
    func skipsLayoutWhenUntrusted() async throws {
        let safari = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            applicationURL: URL(fileURLWithPath: "/Applications/Safari.app")
        )
        let context = WorkspaceContext(
            name: "NoAX",
            symbol: "lock",
            applications: [safari],
            transition: WorkspaceTransition(activationPolicy: .hide)
        )

        let performer = FakeWorkspaceTransitionPerformer()
        let trust = FakeAccessibilityTrustChecker()
        trust.isTrusted = false
        let action = WMWorkspaceTransitionAction(
            context: context,
            provider: FakeAppProvider(),
            performer: performer,
            trustChecker: trust
        )

        try await action.execute()

        #expect(performer.openedApps.map(\.bundleIdentifier) == ["com.apple.Safari"])
        #expect(performer.laidOutApps.isEmpty)
        #expect(performer.steps == [.open("com.apple.Safari", 1)])
    }

    @Test("continues when optional terminal step fails")
    func softFailsOptionalTerminalStep() async throws {
        let context = WorkspaceContext(
            name: "Soft",
            symbol: "circle",
            applications: [],
            transition: WorkspaceTransition(
                activationPolicy: .close,
                terminalCommand: "false"
            )
        )

        let performer = FakeWorkspaceTransitionPerformer()
        performer.terminalError = WMActionError.unknown(reason: "failed")

        let action = WMWorkspaceTransitionAction(
            context: context,
            provider: FakeAppProvider(),
            performer: performer,
            trustChecker: FakeAccessibilityTrustChecker()
        )

        await #expect(throws: Never.self) {
            try await action.execute()
        }

        #expect(performer.resetPolicies == [.close])
        #expect(performer.terminalCommands == ["false"])
    }
}

enum FakeTransitionStep: Equatable {
    case open(String, pid_t)
    case wait(pid_t)
    case layout(String, pid_t?)
}

final class FakeWorkspaceTransitionPerformer: WorkspaceTransitionPerforming {
    private(set) var resetPolicies: [WorkspaceActivationPolicy] = []
    private(set) var openedApps: [WorkspaceApplication] = []
    private(set) var laidOutApps: [WorkspaceApplication] = []
    private(set) var terminalCommands: [String] = []
    private(set) var steps: [FakeTransitionStep] = []

    var terminalError: Error?

    func resetWindows(policy: WorkspaceActivationPolicy, keepApplications _: [WorkspaceApplication]) async throws {
        resetPolicies.append(policy)
    }

    func openApp(_ app: WorkspaceApplication) async throws -> pid_t {
        let processIdentifier = pid_t(openedApps.count + 1)
        openedApps.append(app)
        steps.append(.open(app.bundleIdentifier, processIdentifier))
        return processIdentifier
    }

    func waitForWindows(processIdentifier: pid_t) async {
        steps.append(.wait(processIdentifier))
    }

    func applyWindowLayout(_ app: WorkspaceApplication, processIdentifier: pid_t?) async throws {
        laidOutApps.append(app)
        steps.append(.layout(app.bundleIdentifier, processIdentifier))
    }

    func runTerminalCommand(_ command: String) async throws {
        terminalCommands.append(command)
        if let terminalError {
            throw terminalError
        }
    }
}
