// CURSOR: NEED REVIEW
import Foundation
@testable import dawnAgent
import Testing

@Suite("WMTerminalCommandAction Testing")
struct WMTerminalCommandActionTests {
    @Test("runs command through the runner")
    func runsCommand() throws {
        let runner = FakeTerminalCommandRunner()
        let action = WMTerminalCommandAction(command: "echo hi", runner: runner)

        try action.execute()

        #expect(runner.commands == ["echo hi"])
    }

    @Test("maps runner failures to unknown")
    func mapsRunnerFailure() {
        let runner = FakeTerminalCommandRunner()
        runner.errorToThrow = NSError(domain: "test", code: 1)

        let action = WMTerminalCommandAction(command: "false", runner: runner)

        #expect(throws: WMActionError.self) {
            try action.execute()
        }
    }
}

final class FakeTerminalCommandRunner: TerminalCommandRunning {
    private(set) var commands: [String] = []
    var errorToThrow: Error?

    func run(command: String) throws {
        commands.append(command)
        if let errorToThrow {
            throw errorToThrow
        }
    }
}
