@testable import dawnAgent
import Foundation
import Testing

@Suite("WMTerminalCommandAction Testing")
struct WMTerminalCommandActionTests {
    @Test("runs command through the runner")
    func runsCommand() async throws {
        let runner = FakeTerminalCommandRunner()
        let action = WMTerminalCommandAction(command: "echo hi", runner: runner)

        try await action.execute()

        #expect(runner.commands == ["echo hi"])
    }

    @Test("maps runner failures to unknown")
    func mapsRunnerFailure() async {
        let runner = FakeTerminalCommandRunner()
        runner.errorToThrow = NSError(domain: "test", code: 1)

        let action = WMTerminalCommandAction(command: "false", runner: runner)

        await #expect(throws: WMActionError.self) {
            try await action.execute()
        }
    }
}

final class FakeTerminalCommandRunner: TerminalCommandRunning, @unchecked Sendable {
    private(set) var commands: [String] = []
    var errorToThrow: Error?

    func run(command: String) async throws {
        commands.append(command)
        if let errorToThrow {
            throw errorToThrow
        }
    }
}
