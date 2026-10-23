// CURSOR: NEED REVIEW
import Foundation

protocol TerminalCommandRunning {
    func run(command: String) throws
}

struct ProcessTerminalCommandRunner: TerminalCommandRunning {
    func run(command: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw WMActionError.unknown(
                reason: "Terminal command exited with status \(process.terminationStatus)"
            )
        }
    }
}
