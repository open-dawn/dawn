import Foundation

protocol FocusModeApplying {
    func applyFocusMode(named name: String) throws
}

struct ShortcutsFocusModeApplicator: FocusModeApplying {
    private let executableURL: URL

    init(executableURL: URL = URL(fileURLWithPath: "/usr/bin/shortcuts")) {
        self.executableURL = executableURL
    }

    func applyFocusMode(named name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw WMActionError.unknown(reason: "Focus mode name is empty")
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["run", trimmed]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw WMActionError.unknown(reason: error.localizedDescription)
        }

        guard process.terminationStatus == 0 else {
            throw WMActionError.unknown(
                reason: "shortcuts run exited with status \(process.terminationStatus)"
            )
        }
    }
}
