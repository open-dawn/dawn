import AppKit
import libdawn

@MainActor
struct SystemRunningApplicationSelector: ApplicationSelecting {
    func selectApplication() async throws -> WorkspaceApplication? {
        let candidates = Self.runningCandidates()

        guard !candidates.isEmpty else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            let alert = NSAlert()
            alert.messageText = "running-apps picker"
            alert.informativeText = "Temporary picker. Choose a running app to protect."
            alert.addButton(withTitle: "Add")
            alert.addButton(withTitle: "Cancel")

            let popup = NSPopUpButton(
                frame: NSRect(x: 0, y: 0, width: 320, height: 24),
                pullsDown: false
            )

            for candidate in candidates {
                popup.addItem(
                    withTitle: "\(candidate.displayName) — \(candidate.bundleIdentifier)"
                )
            }

            alert.accessoryView = popup

            let response = alert.runModal()
            guard response == .alertFirstButtonReturn else {
                continuation.resume(returning: nil)
                return
            }

            let index = popup.indexOfSelectedItem
            guard candidates.indices.contains(index) else {
                continuation.resume(returning: nil)
                return
            }

            continuation.resume(returning: candidates[index])
        }
    }

    private static func runningCandidates() -> [WorkspaceApplication] {
        var seenBundleIdentifiers = Set<String>()
        var candidates: [WorkspaceApplication] = []

        for application in NSWorkspace.shared.runningApplications {
            guard application.activationPolicy != .prohibited else {
                continue
            }

            guard let bundleIdentifier = application.bundleIdentifier,
                !bundleIdentifier.isEmpty
            else {
                continue
            }

            let normalized = bundleIdentifier.lowercased()
            guard seenBundleIdentifiers.insert(normalized).inserted else {
                continue
            }

            let displayName = application.localizedName ?? bundleIdentifier

            candidates.append(
                WorkspaceApplication(
                    bundleIdentifier: bundleIdentifier,
                    displayName: displayName,
                    applicationURL: application.bundleURL
                )
            )
        }

        return candidates.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }
}
