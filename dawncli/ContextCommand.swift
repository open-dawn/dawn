import ArgumentParser
import Foundation

struct JSONOutput: ParsableArguments {
    @Flag(name: .long, help: "Print JSON.")
    var json = false
}

struct ContextIdentifier: ExpressibleByArgument, Equatable {
    let uuid: UUID

    init(uuid: UUID) {
        self.uuid = uuid
    }

    init?(argument: String) {
        guard let uuid = UUID(uuidString: argument) else { return nil }
        self.uuid = uuid
    }
}

struct ContextCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "context",
        abstract: "List and change workspace contexts.",
        subcommands: [
            List.self,
            Show.self
        ]
    )
}

extension ContextCommand {
    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List workspace contexts."
        )

        @Flag(name: .long, help: "Show only archived contexts.")
        var archived = false

        @OptionGroup var output: JSONOutput

        func run() async throws {
            print(
                try await AgentSession.perform { ask in
                    try await ContextClient.list(
                        archivedOnly: archived,
                        json: output.json,
                        ask: ask
                    )
                }
            )
        }
    }

    struct Show: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Show one workspace context."
        )

        @Argument(help: "Context identifier.")
        var id: ContextIdentifier

        @OptionGroup var output: JSONOutput

        func run() async throws {
            print(
                try await AgentSession.perform { ask in
                    try await ContextClient.show(
                        id: id.uuid,
                        json: output.json,
                        ask: ask
                    )
                }
            )
        }
    }
}
