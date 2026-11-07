import AppKit
import libdawn

struct AgentInstanceGuard: Equatable {
    let currentProcessIdentifier: Int32
    let runningProcessIdentifiers: [Int32]

    var shouldTerminate: Bool {
        runningProcessIdentifiers.contains { identifier in
            identifier != currentProcessIdentifier
        }
    }

    static func shouldTerminateCurrentInstance() -> Bool {
        let bundleIdentifier = Bundle.main.bundleIdentifier
            ?? EventBusMachService.agentBundleIdentifier
        let running = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleIdentifier
        ).map(\.processIdentifier)

        return AgentInstanceGuard(
            currentProcessIdentifier: ProcessInfo.processInfo.processIdentifier,
            runningProcessIdentifiers: running
        ).shouldTerminate
    }
}
