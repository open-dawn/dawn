import ArgumentParser

struct AccessibilityCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "accessibility",
        abstract: "Check or prompt for accessibility trust.",
        subcommands: [
            Status.self,
            Prompt.self
        ]
    )
}

extension AccessibilityCommand {
    struct Status: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Print whether dawnAgent is trusted for accessibility."
        )

        @OptionGroup var output: JSONOutput

        func run() async throws {
            print(
                try await AgentSession.perform { ask in
                    try await AccessibilityClient.status(json: output.json, ask: ask)
                }
            )
        }
    }

    struct Prompt: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Ask macOS to prompt for accessibility trust."
        )

        @OptionGroup var output: JSONOutput

        func run() async throws {
            print(
                try await AgentSession.perform { ask in
                    try await AccessibilityClient.prompt(json: output.json, ask: ask)
                }
            )
        }
    }
}
