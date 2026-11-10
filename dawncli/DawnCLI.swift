import ArgumentParser

struct DawnCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dawncli",
        abstract: "Talk to dawnAgent.",
        subcommands: [
            Status.self,
            ContextCommand.self,
            SettingsCommand.self,
            AccessibilityCommand.self
        ]
    )
}

extension DawnCLI {
    struct Status: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Ask dawnAgent whether it is reachable."
        )

        func run() async throws {
            print(try await AgentStatus.query())
        }
    }
}
