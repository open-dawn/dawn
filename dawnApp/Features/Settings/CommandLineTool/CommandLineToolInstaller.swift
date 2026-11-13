import Foundation

enum CommandLineToolLookup: Equatable, Sendable {
    case missing
    case brokenSymlink
    case resolved(URL)

    var needsInstall: Bool {
        switch self {
        case .missing, .brokenSymlink:
            true
        case .resolved:
            false
        }
    }

    static func interpret(
        standardOutput: String,
        terminationStatus: Int32,
        pathExists: (String) -> Bool
    ) throws(CommandLineToolLookupError) -> CommandLineToolLookup {
        guard terminationStatus == 0 || terminationStatus == 1 else {
            throw .checkFailed
        }

        guard terminationStatus == 0 else {
            return .missing
        }

        let lines = standardOutput.split(whereSeparator: \.isNewline).map(String.init)
        guard let path = lines.last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })?
            .trimmingCharacters(in: .whitespaces),
            path.hasPrefix("/")
        else {
            return .missing
        }

        let resolved = URL(filePath: path).resolvingSymlinksInPath()
        guard pathExists(resolved.path(percentEncoded: false)) else {
            return .brokenSymlink
        }

        return .resolved(resolved)
    }
}

enum CommandLineToolLookupError: Error, Equatable {
    case checkFailed
}

enum CommandLineToolInstallError: Error, Equatable {
    case canceled
    case failed(String)
}

protocol CommandLineToolInstalling: Sendable {
    func lookup() async throws -> CommandLineToolLookup
    func installLink(from bundleCommandURL: URL, to linkURL: URL) async throws(CommandLineToolInstallError)
}

enum CommandLineToolPaths {
    static let commandName = "dawncli"
    static let linkURL = URL(filePath: "/usr/local/bin/dawncli")

    static func bundleCommandURL(bundle: Bundle = .main) -> URL {
        bundle.bundleURL.appending(
            path: "Contents/MacOS/\(commandName)",
            directoryHint: .notDirectory
        )
    }
}

enum CommandLineToolInstallScript {
    static func appleScript(bundleCommandURL: URL, linkURL: URL) -> String {
        let directory = directoryPath(linkURL.deletingLastPathComponent())
        let bundlePath = shellQuote(bundleCommandURL.path(percentEncoded: false))
        let destination = shellQuote(linkURL.path(percentEncoded: false))
        let command = [
            "mkdir -p \(shellQuote(directory))",
            "ln -sfn \(bundlePath) \(destination)",
        ].joined(separator: " && ")

        return "do shell script \(appleScriptQuote(command)) with administrator privileges"
    }

    static func isAuthorizationCanceled(standardError: String) -> Bool {
        standardError.contains("User canceled") || standardError.contains("(-128)")
    }

    private static func directoryPath(_ url: URL) -> String {
        var path = url.path(percentEncoded: false)
        if path.count > 1, path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptQuote(_ command: String) -> String {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}

struct ShellCommandLineToolInstaller: CommandLineToolInstalling {
    func lookup() async throws -> CommandLineToolLookup {
        let output = try await CommandLineToolProcess.run(
            executable: URL(filePath: "/bin/zsh"),
            arguments: ["-lc", "whence -p \(CommandLineToolPaths.commandName)"]
        )

        return try CommandLineToolLookup.interpret(
            standardOutput: output.standardOutput,
            terminationStatus: output.terminationStatus,
            pathExists: CommandLineToolProcess.fileExists
        )
    }

    func installLink(from bundleCommandURL: URL, to linkURL: URL) async throws(CommandLineToolInstallError) {
        guard CommandLineToolProcess.isExecutable(bundleCommandURL) else {
            throw .failed("dawncli is not in this copy of DAWN.")
        }

        let script = CommandLineToolInstallScript.appleScript(
            bundleCommandURL: bundleCommandURL,
            linkURL: linkURL
        )
        let output: CommandLineToolProcess.Output
        do {
            output = try await CommandLineToolProcess.run(
                executable: URL(filePath: "/usr/bin/osascript"),
                arguments: ["-e", script]
            )
        } catch {
            throw .failed("Could not install dawncli.")
        }

        guard output.terminationStatus == 0 else {
            if CommandLineToolInstallScript.isAuthorizationCanceled(standardError: output.standardError) {
                throw .canceled
            }

            throw .failed("Could not install dawncli.")
        }
    }
}

private enum CommandLineToolProcess {
    struct Output {
        var terminationStatus: Int32
        var standardOutput: String
        var standardError: String
    }

    static func run(executable: URL, arguments: [String]) async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = executable
                process.arguments = arguments

                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                process.waitUntilExit()
                continuation.resume(
                    returning: Output(
                        terminationStatus: process.terminationStatus,
                        standardOutput: read(outputPipe),
                        standardError: read(errorPipe)
                    )
                )
            }
        }
    }

    static func fileExists(_ path: String) -> Bool {
        path.withCString { pointer in
            var info = stat()
            return stat(pointer, &info) == 0
        }
    }

    static func isExecutable(_ url: URL) -> Bool {
        access(url.path(percentEncoded: false), X_OK) == 0
    }

    private static func read(_ pipe: Pipe) -> String {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(bytes: data, encoding: .utf8) ?? ""
    }
}
