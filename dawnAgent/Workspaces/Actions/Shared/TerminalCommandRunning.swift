import Foundation

protocol TerminalCommandRunning: Sendable {
    func run(command: String) async throws
}

struct ProcessTerminalCommandRunner: TerminalCommandRunning {
    func run(command: String) async throws {
        try await Task.detached(priority: .userInitiated) {
            try RunningProcessRegistry().start(command: command)
        }
        .value
    }
}

private final class RunningProcessRegistry {
    private let process = Process()

    func start(command: String) throws {
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [self] finished in
            finished.terminationHandler = nil
        }
        try process.run()
    }
}
