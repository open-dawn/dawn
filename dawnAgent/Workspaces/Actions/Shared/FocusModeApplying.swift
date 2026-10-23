// CURSOR: NEED REVIEW
import Foundation

protocol FocusModeApplying {
    /// Enables the given macOS Focus mode when the system allows it.
    func applyFocusMode(named name: String) throws
}

/// Applies Focus by running a Shortcuts shortcut with the same name as the Focus mode.
///
/// There is no public API to set Focus directly. Create a Shortcut named e.g.
/// "Do Not Disturb" whose action is **Set Focus → Do Not Disturb**, then pass
/// that same name in `WorkspaceTransition.setFocus`.
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
