import ArgumentParser

struct SettingsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "settings",
        abstract: "Read and change DAWN settings.",
        subcommands: [
            Get.self,
            Set.self,
            Protect.self
        ]
    )
}

extension SettingsCommand {
    struct Get: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Print the current settings."
        )

        @OptionGroup var output: JSONOutput

        func run() async throws {
            print(
                try await AgentSession.perform { ask in
                    try await SettingsClient.get(json: output.json, ask: ask)
                }
            )
        }
    }

    struct Set: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Change one boolean setting."
        )

        @Argument(help: "launch-at-login, menu-bar, force-quit, or analytics.")
        var field: SettingsField

        @Argument(help: "true or false.")
        var value: Bool

        @OptionGroup var output: JSONOutput

        func run() async throws {
            print(
                try await AgentSession.perform { ask in
                    try await SettingsClient.set(
                        field: field,
                        value: value,
                        json: output.json,
                        ask: ask
                    )
                }
            )
        }
    }

    struct Protect: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "protect",
            abstract: "Change apps that stay open across context switches.",
            subcommands: [
                Add.self,
                Remove.self
            ]
        )
    }
}

extension SettingsCommand.Protect {
    struct Add: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Protect an app."
        )

        @Argument(help: "Bundle identifier.")
        var bundleIdentifier: String

        @Option(name: .long, help: "Name shown for the app.")
        var name: String

        @OptionGroup var output: JSONOutput

        func run() async throws {
            print(
                try await AgentSession.perform { ask in
                    try await SettingsClient.protect(
                        bundleIdentifier: bundleIdentifier,
                        displayName: name,
                        json: output.json,
                        ask: ask
                    )
                }
            )
        }
    }

    struct Remove: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Stop protecting an app."
        )

        @Argument(help: "Bundle identifier.")
        var bundleIdentifier: String

        @OptionGroup var output: JSONOutput

        func run() async throws {
            print(
                try await AgentSession.perform { ask in
                    try await SettingsClient.unprotect(
                        bundleIdentifier: bundleIdentifier,
                        json: output.json,
                        ask: ask
                    )
                }
            )
        }
    }
}
