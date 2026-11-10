import ArgumentParser
import Foundation
import libdawn

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
            Show.self,
            Switch.self,
            Delete.self,
            Archive.self,
            Unarchive.self
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

    struct Switch: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Switch to a workspace context."
        )

        @Argument(help: "Context identifier.")
        var id: ContextIdentifier

        @OptionGroup var output: JSONOutput

        func run() async throws {
            try await runMutation(
                id: id.uuid,
                verb: "switched",
                event: .switchContext(SwitchContextEvent(contextID: id.uuid)),
                json: output.json
            )
        }
    }

    struct Delete: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Delete a workspace context."
        )

        @Argument(help: "Context identifier.")
        var id: ContextIdentifier

        @OptionGroup var output: JSONOutput

        func run() async throws {
            try await runMutation(
                id: id.uuid,
                verb: "deleted",
                event: .deleteContext(DeleteContextEvent(contextID: id.uuid)),
                json: output.json
            )
        }
    }

    struct Archive: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Archive a workspace context."
        )

        @Argument(help: "Context identifier.")
        var id: ContextIdentifier

        @OptionGroup var output: JSONOutput

        func run() async throws {
            try await runMutation(
                id: id.uuid,
                verb: "archived",
                event: .archiveContext(ArchiveContextEvent(contextID: id.uuid)),
                json: output.json
            )
        }
    }

    struct Unarchive: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Restore an archived workspace context."
        )

        @Argument(help: "Context identifier.")
        var id: ContextIdentifier

        @OptionGroup var output: JSONOutput

        func run() async throws {
            try await runMutation(
                id: id.uuid,
                verb: "unarchived",
                event: .unarchiveContext(UnarchiveContextEvent(contextID: id.uuid)),
                json: output.json
            )
        }
    }
}

private func runMutation(
    id: UUID,
    verb: String,
    event: Event,
    json: Bool
) async throws {
    let text = try await AgentSession.perform { ask in
        try await ContextClient.mutate(
            id: id,
            verb: verb,
            event: event,
            json: json,
            ask: ask
        )
    }
    print(text)
}
