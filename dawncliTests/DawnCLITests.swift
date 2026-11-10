import ArgumentParser
import Testing

@Suite("DawnCLI")
struct DawnCLITests {
    @Test("registers the root commands")
    func registersRootCommands() {
        let help = DawnCLI.helpMessage(includeHidden: false, columns: 80)
        #expect(help.contains("status"))
        #expect(help.contains("context"))
    }

    @Test("help lists every command")
    func helpListsCommands() {
        let help = DawnCLI.helpMessage(includeHidden: false, columns: 80)
        #expect(help == Self.help)
    }

    @Test("help flags show every command", arguments: ["--help", "-h", "help"])
    func helpFlagsShowCommands(flag: String) throws {
        var command = try DawnCLI.parseAsRoot([flag])

        do {
            try command.run()
            Issue.record("Help should exit")
        } catch {
            #expect(DawnCLI.exitCode(for: error) == .success)
            #expect(DawnCLI.fullMessage(for: error, columns: 80) == Self.help)
        }
    }

    @Test("running with no arguments shows every command")
    func noArgumentsShowsCommands() throws {
        var command = try DawnCLI.parseAsRoot([])

        do {
            try command.run()
            Issue.record("Expected help")
        } catch {
            #expect(DawnCLI.exitCode(for: error) == .success)
            #expect(DawnCLI.fullMessage(for: error, columns: 80) == Self.help)
        }
    }

    @Test("status parses with no extra arguments")
    func statusParses() throws {
        let command = try DawnCLI.parseAsRoot(["status"])
        #expect(command is DawnCLI.Status)
    }

    @Test("rejects an unknown command")
    func rejectsUnknownCommand() {
        expectValidationFailure(
            ["nope"],
            """
            Error: Unexpected argument 'nope'
            Usage: dawncli <subcommand>
              See 'dawncli --help' for more information.
            """
        )
    }

    @Test("rejects extra status arguments")
    func rejectsExtraStatusArguments() {
        expectValidationFailure(
            ["status", "extra"],
            """
            Error: Unexpected argument 'extra'
            Usage: dawncli status
              See 'dawncli status --help' for more information.
            """
        )
    }

    private static let help = """
    OVERVIEW: Talk to dawnAgent.

    USAGE: dawncli <subcommand>

    OPTIONS:
      -h, --help              Show help information.

    SUBCOMMANDS:
      status                  Ask dawnAgent whether it is reachable.
      context                 List and change workspace contexts.

      See 'dawncli help <subcommand>' for detailed help.
    """

    private func expectValidationFailure(
        _ arguments: [String],
        _ message: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        do {
            _ = try DawnCLI.parseAsRoot(arguments)
            Issue.record("Expected parsing to fail", sourceLocation: sourceLocation)
        } catch {
            #expect(
                DawnCLI.exitCode(for: error) == .validationFailure,
                sourceLocation: sourceLocation
            )
            #expect(
                DawnCLI.fullMessage(for: error, columns: 80) == message,
                sourceLocation: sourceLocation
            )
        }
    }
}
