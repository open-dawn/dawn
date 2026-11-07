import AppKit
import Testing
@testable import dawnApp

@MainActor
@Suite("Embedded agent launcher")
struct EmbeddedAgentLauncherTests {
    @Test("Leaves a running agent alone")
    func skipsWhenAgentIsRunning() async {
        let opener = AgentOpenerSpy()
        let launcher = EmbeddedAgentLauncher(
            agentURL: URL(filePath: "/Applications/DAWN.app/Contents/Library/LoginItems/dawnAgent.app"),
            isAgentRunning: { true },
            opener: opener
        )

        await launcher.launchIfNeeded()

        #expect(opener.launchCount == 0)
    }

    @Test("Reports a missing embedded bundle")
    func reportsMissingBundle() async {
        let opener = AgentOpenerSpy()
        let failures = FailureBox()
        let launcher = EmbeddedAgentLauncher(
            agentURL: nil,
            isAgentRunning: { false },
            opener: opener,
            logFailure: { failures.values.append($0) }
        )

        await launcher.launchIfNeeded()

        #expect(opener.launchCount == 0)
        #expect(failures.values == [.missingBundle])
    }

    @Test("Opens the embedded agent without activating it")
    func opensWithoutActivating() async {
        let agentURL = URL(
            filePath: "/Applications/DAWN.app/Contents/Library/LoginItems/dawnAgent.app"
        )
        let opener = AgentOpenerSpy()
        let launcher = EmbeddedAgentLauncher(
            agentURL: agentURL,
            isAgentRunning: { false },
            opener: opener
        )

        await launcher.launchIfNeeded()

        #expect(opener.launchCount == 1)
        #expect(opener.url == agentURL)
        #expect(opener.configuration?.activates == false)
    }

    @Test("Logs an open failure and continues")
    func logsOpenFailure() async {
        let opener = AgentOpenerSpy()
        opener.error = AgentOpenError()
        let failures = FailureBox()
        let launcher = EmbeddedAgentLauncher(
            agentURL: URL(filePath: "/Applications/DAWN.app/Contents/Library/LoginItems/dawnAgent.app"),
            isAgentRunning: { false },
            opener: opener,
            logFailure: { failures.values.append($0) }
        )

        await launcher.launchIfNeeded()

        #expect(opener.launchCount == 1)
        #expect(failures.values == [.openFailed(AgentOpenError().localizedDescription)])
    }
}

@MainActor
private final class AgentOpenerSpy: EmbeddedAgentOpening {
    var launchCount = 0
    var url: URL?
    var configuration: NSWorkspace.OpenConfiguration?
    var error: Error?

    func launch(
        at url: URL,
        configuration: NSWorkspace.OpenConfiguration
    ) async throws {
        launchCount += 1
        self.url = url
        self.configuration = configuration
        if let error {
            throw error
        }
    }
}

private struct AgentOpenError: LocalizedError {
    var errorDescription: String? { "The workspace could not open dawnAgent." }
}

@MainActor
private final class FailureBox {
    var values: [EmbeddedAgentLaunchFailure] = []
}
