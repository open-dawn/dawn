import ArgumentParser
import Foundation
import libdawn

struct JSONOutput: ParsableArguments {
    @Flag(name: .long, help: "Print JSON.")
    var json = false
}

struct ActivationChoice: ExpressibleByArgument, Equatable {
    let policy: WorkspaceActivationPolicy

    init?(argument: String) {
        guard let policy = WorkspaceActivationPolicy(rawValue: argument) else { return nil }
        self.policy = policy
    }
}

struct WorkspaceIdentifier: ExpressibleByArgument, Equatable {
    let uuid: UUID

    init(uuid: UUID) {
        self.uuid = uuid
    }

    init?(argument: String) {
        guard let uuid = UUID(uuidString: argument) else { return nil }
        self.uuid = uuid
    }
}

struct WorkspaceCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "workspace",
        abstract: "List and change workspaces.",
        subcommands: [
            List.self,
            Show.self,
            Switch.self,
            Create.self,
            Update.self,
            Delete.self,
            Archive.self,
            Unarchive.self
        ]
    )
}

extension WorkspaceCommand {
    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List workspaces."
        )

        @Flag(name: .long, help: "Show only archived workspaces.")
        var archived = false

        @OptionGroup var output: JSONOutput

        func run() async throws {
            print(
                try await AgentSession.perform { ask in
                    try await WorkspaceClient.list(
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
            abstract: "Show one workspace."
        )

        @Argument(help: "Workspace identifier.")
        var id: WorkspaceIdentifier

        @OptionGroup var output: JSONOutput

        func run() async throws {
            print(
                try await AgentSession.perform { ask in
                    try await WorkspaceClient.show(
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
            abstract: "Switch to a workspace."
        )

        @Argument(help: "Workspace identifier.")
        var id: WorkspaceIdentifier

        @OptionGroup var output: JSONOutput

        func run() async throws {
            try await runMutation(
                id: id.uuid,
                verb: "switched",
                event: .switchWorkspace(SwitchWorkspaceEvent(workspaceID: id.uuid)),
                json: output.json
            )
        }
    }

    struct Delete: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Delete a workspace."
        )

        @Argument(help: "Workspace identifier.")
        var id: WorkspaceIdentifier

        @OptionGroup var output: JSONOutput

        func run() async throws {
            try await runMutation(
                id: id.uuid,
                verb: "deleted",
                event: .deleteWorkspace(DeleteWorkspaceEvent(workspaceID: id.uuid)),
                json: output.json
            )
        }
    }

    struct Archive: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Archive a workspace."
        )

        @Argument(help: "Workspace identifier.")
        var id: WorkspaceIdentifier

        @OptionGroup var output: JSONOutput

        func run() async throws {
            try await runMutation(
                id: id.uuid,
                verb: "archived",
                event: .archiveWorkspace(ArchiveWorkspaceEvent(workspaceID: id.uuid)),
                json: output.json
            )
        }
    }

    struct Unarchive: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Restore an archived workspace."
        )

        @Argument(help: "Workspace identifier.")
        var id: WorkspaceIdentifier

        @OptionGroup var output: JSONOutput

        func run() async throws {
            try await runMutation(
                id: id.uuid,
                verb: "unarchived",
                event: .unarchiveWorkspace(UnarchiveWorkspaceEvent(workspaceID: id.uuid)),
                json: output.json
            )
        }
    }

    struct Create: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Create a workspace."
        )

        @Option(name: .long, help: "Workspace name.")
        var name: String?

        @Option(name: .long, help: "SF Symbol name.")
        var symbol: String?

        @Option(
            name: .customLong("app"),
            parsing: .singleValue,
            help: "Bundle identifier to include. Repeat for each app."
        )
        var apps: [String] = []

        @Option(name: .long, help: "How other apps are treated: hide, merge, or close.")
        var activation: ActivationChoice?

        @Option(
            name: .customLong("terminal-command"),
            help: "Shell command to run when the workspace opens."
        )
        var terminalCommand: String?

        @Option(
            name: .long,
            help: "JSON file with name, symbol, applications, and transition. Replaces the other flags."
        )
        var from: String?

        @OptionGroup var output: JSONOutput

        mutating func validate() throws {
            if from != nil {
                if hasFieldFlags {
                    throw ValidationError("Pass either --from or the field flags, not both.")
                }
                return
            }

            guard let name, !name.isEmpty, let symbol, !symbol.isEmpty else {
                throw ValidationError("Pass --name and --symbol, or --from.")
            }
        }

        func run() async throws {
            let request = try makeRequest()
            let text = try await AgentSession.perform { ask in
                try await WorkspaceClient.create(
                    request: request,
                    json: output.json,
                    ask: ask
                )
            }
            print(text)
        }

        private var hasFieldFlags: Bool {
            name != nil || symbol != nil || !apps.isEmpty || activation != nil || terminalCommand != nil
        }

        private func makeRequest() throws -> CreateWorkspaceEvent {
            if let from {
                return try CLIJSON.decode(CreateWorkspaceEvent.self, from: from)
            }

            let command = terminalCommand?.isEmpty == true ? nil : terminalCommand
            return CreateWorkspaceEvent(
                name: name ?? "",
                symbol: symbol ?? "",
                applications: try WorkspaceClient.applications(from: apps),
                transition: WorkspaceTransition(
                    activationPolicy: activation?.policy ?? .hide,
                    terminalCommand: command
                )
            )
        }
    }

    struct Update: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Change a workspace."
        )

        @Argument(help: "Workspace identifier.")
        var id: WorkspaceIdentifier

        @Option(name: .long, help: "Workspace name.")
        var name: String?

        @Option(name: .long, help: "SF Symbol name.")
        var symbol: String?

        @Option(
            name: .customLong("app"),
            parsing: .singleValue,
            help: "Replace the app list with these bundle identifiers."
        )
        var apps: [String] = []

        @Flag(
            name: .customLong("clear-apps"),
            help: "Remove every app from the workspace."
        )
        var clearApps = false

        @Option(name: .long, help: "How other apps are treated: hide, merge, or close.")
        var activation: ActivationChoice?

        @Option(
            name: .customLong("terminal-command"),
            help: "Shell command to run when the workspace opens. Pass an empty string to clear it."
        )
        var terminalCommand: String?

        @Option(
            name: .long,
            help: "JSON file for the whole workspace. Its id must match the argument."
        )
        var from: String?

        @OptionGroup var output: JSONOutput

        mutating func validate() throws {
            if from != nil {
                if hasFieldFlags {
                    throw ValidationError("Pass either --from or the field flags, not both.")
                }
                return
            }

            if !apps.isEmpty, clearApps {
                throw ValidationError("Pass either --app or --clear-apps, not both.")
            }

            guard hasFieldFlags else {
                throw ValidationError("Pass a field to change, or --from.")
            }
        }

        func run() async throws {
            let replacement = try from.map {
                try CLIJSON.decode(Workspace.self, from: $0)
            }
            let edits = WorkspaceEdits(
                name: name,
                symbol: symbol,
                bundleIdentifiers: apps.isEmpty ? nil : apps,
                clearsApplications: clearApps,
                activation: activation?.policy,
                terminalCommand: terminalCommand?.isEmpty == true ? nil : terminalCommand,
                clearsTerminalCommand: terminalCommand?.isEmpty == true
            )
            let text = try await AgentSession.perform { ask in
                try await WorkspaceClient.update(
                    id: id.uuid,
                    edits: edits,
                    replacement: replacement,
                    json: output.json,
                    ask: ask
                )
            }
            print(text)
        }

        private var hasFieldFlags: Bool {
            name != nil
                || symbol != nil
                || !apps.isEmpty
                || clearApps
                || activation != nil
                || terminalCommand != nil
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
        try await WorkspaceClient.mutate(
            id: id,
            verb: verb,
            event: event,
            json: json,
            ask: ask
        )
    }
    print(text)
}
