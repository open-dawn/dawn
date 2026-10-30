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
                .open("com.apple.Safari"),
                .wait("com.apple.Safari"),
                .layout("com.apple.Safari"),
                .open("com.apple.Notes"),
                .wait("com.apple.Notes"),
                .layout("com.apple.Notes"),
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
                .open("com.apple.Notes"),
                .wait("com.apple.Notes"),
                .layout("com.apple.Notes"),
                .layout("com.apple.Safari"),
            ]
        )
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
        #expect(performer.steps == [.open("com.apple.Safari")])
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
    case open(String)
    case wait(String)
    case layout(String)
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

    func openApp(_ app: WorkspaceApplication) async throws {
        openedApps.append(app)
        steps.append(.open(app.bundleIdentifier))
    }

    func waitForWindows(bundleIdentifier: String) async {
        steps.append(.wait(bundleIdentifier))
    }

    func applyWindowLayout(_ app: WorkspaceApplication) async throws {
        laidOutApps.append(app)
        steps.append(.layout(app.bundleIdentifier))
    }

    func runTerminalCommand(_ command: String) async throws {
        terminalCommands.append(command)
        if let terminalError {
            throw terminalError
        }
    }
}
