// CURSOR: NEED REVIEW
import Foundation
import libdawn
@testable import dawnAgent
import Testing

@Suite("WMWorkspaceTransitionAction Testing")
struct WMWorkspaceTransitionActionTests {
    @Test("hide policy resets then opens all apps, then terminal")
    func hideOpensAllThenTerminal() async throws {
        let safari = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            applicationURL: URL(fileURLWithPath: "/Applications/Safari.app")
        )
        let context = WorkspaceContext(
            name: "Work",
            symbol: "briefcase",
            applications: [safari],
            transition: WorkspaceTransition(
                activationPolicy: .hide,
                terminalCommand: "echo dawn"
            )
        )

        let performer = FakeWorkspaceTransitionPerformer()
        let provider = FakeAppProvider()
        let action = WMWorkspaceTransitionAction(
            context: context,
            provider: provider,
            performer: performer
        )

        try await action.execute()

        #expect(performer.resetPolicies == [.hide])
        #expect(performer.openedApps.map(\.bundleIdentifier) == ["com.apple.Safari"])
        #expect(performer.terminalCommands == ["echo dawn"])
    }

    @Test("merge policy only opens apps that are not already running")
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
        let action = WMWorkspaceTransitionAction(
            context: context,
            provider: provider,
            performer: performer
        )

        try await action.execute()

        #expect(performer.resetPolicies == [.merge])
        #expect(performer.openedApps.map(\.bundleIdentifier) == ["com.apple.Notes"])
        #expect(performer.terminalCommands.isEmpty)
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
            performer: performer
        )

        await #expect(throws: Never.self) {
            try await action.execute()
        }

        #expect(performer.resetPolicies == [.close])
        #expect(performer.terminalCommands == ["false"])
    }
}

final class FakeWorkspaceTransitionPerformer: WorkspaceTransitionPerforming {
    private(set) var resetPolicies: [ActivationPolicy] = []
    private(set) var openedApps: [WorkspaceApplication] = []
    private(set) var terminalCommands: [String] = []

    var terminalError: Error?

    func resetWindows(policy: ActivationPolicy, keepApplications _: [WorkspaceApplication]) async throws {
        resetPolicies.append(policy)
    }

    func openApp(_ app: WorkspaceApplication) async throws {
        openedApps.append(app)
    }

    func runTerminalCommand(_ command: String) async throws {
        terminalCommands.append(command)
        if let terminalError {
            throw terminalError
        }
    }
}
