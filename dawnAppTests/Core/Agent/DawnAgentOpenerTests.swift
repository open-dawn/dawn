import Foundation
import Testing
@testable import dawnApp

@MainActor
@Suite("Dawn agent opener")
struct DawnAgentOpenerTests {
    @Test("openDawnAgentIfNeeded leaves a running agent alone")
    func skipsWhenAgentIsRunning() async {
        let opener = AgentOpenerSpy()
        let sut = DawnAgentOpener(
            agentAppURL: URL(
                filePath: "/Applications/DAWN.app/Contents/Library/LoginItems/dawnAgent.app"
            ),
            isAgentRunning: { true },
            opener: opener
        )

        await sut.openDawnAgentIfNeeded()

        #expect(opener.openCount == 0)
    }

    @Test("openDawnAgentIfNeeded starts a stopped agent")
    func startsWhenAgentIsStopped() async {
        let agentURL = URL(
            filePath: "/Applications/DAWN.app/Contents/Library/LoginItems/dawnAgent.app"
        )
        let opener = AgentOpenerSpy()
        let sut = DawnAgentOpener(
            agentAppURL: agentURL,
            isAgentRunning: { false },
            opener: opener
        )

        await sut.openDawnAgentIfNeeded()

        #expect(opener.openCount == 1)
        #expect(opener.url == agentURL)
    }

    @Test("openDawnAgent always attempts a launch")
    func openAlwaysAttemptsLaunch() async {
        let agentURL = URL(
            filePath: "/Applications/DAWN.app/Contents/Library/LoginItems/dawnAgent.app"
        )
        let opener = AgentOpenerSpy()
        let sut = DawnAgentOpener(
            agentAppURL: agentURL,
            isAgentRunning: { true },
            opener: opener
        )

        await sut.openDawnAgent()

        #expect(opener.openCount == 1)
        #expect(opener.url == agentURL)
    }

    @Test("Reports a missing embedded bundle")
    func reportsMissingBundle() async {
        let opener = AgentOpenerSpy()
        let failures = FailureBox()
        let sut = DawnAgentOpener(
            agentAppURL: nil,
            isAgentRunning: { false },
            opener: opener,
            logFailure: { failures.values.append($0) }
        )

        await sut.openDawnAgentIfNeeded()

        #expect(opener.openCount == 0)
        #expect(failures.values == [.missingBundle])
    }

    @Test("Logs an open failure and continues")
    func logsOpenFailure() async {
        let opener = AgentOpenerSpy()
        opener.error = AgentOpenError()
        let failures = FailureBox()
        let sut = DawnAgentOpener(
            agentAppURL: URL(
                filePath: "/Applications/DAWN.app/Contents/Library/LoginItems/dawnAgent.app"
            ),
            isAgentRunning: { false },
            opener: opener,
            logFailure: { failures.values.append($0) }
        )

        await sut.openDawnAgent()

        #expect(opener.openCount == 1)
        #expect(failures.values == [.openFailed(AgentOpenError().localizedDescription)])
    }
}

@MainActor
private final class AgentOpenerSpy: DawnAgentOpening {
    var openCount = 0
    var url: URL?
    var error: Error?

    func open(at url: URL) async throws {
        openCount += 1
        self.url = url
        if let error {
            throw error
        }
    }
}

private struct AgentOpenError: LocalizedError {
    var errorDescription: String? { "The agent executable could not be started." }
}

@MainActor
private final class FailureBox {
    var values: [DawnAgentOpenFailure] = []
}
