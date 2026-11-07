import AppKit
import dawnLogging
import libdawn

enum DawnAgentOpenFailure: Equatable {
    case missingBundle
    case openFailed(String)
}

@MainActor
protocol DawnAgentOpening {
    func open(at url: URL) async throws
}

@MainActor
struct DawnAgentOpener {
    static let bundleIdentifier = EventBusMachService.agentBundleIdentifier

    private let agentAppURL: URL?
    private let isAgentRunning: () -> Bool
    private let opener: any DawnAgentOpening
    private let logFailure: (DawnAgentOpenFailure) -> Void

    init(
        agentAppURL: URL?,
        isAgentRunning: @escaping () -> Bool,
        opener: any DawnAgentOpening,
        logFailure: @escaping (DawnAgentOpenFailure) -> Void = { _ in }
    ) {
        self.agentAppURL = agentAppURL
        self.isAgentRunning = isAgentRunning
        self.opener = opener
        self.logFailure = logFailure
    }

    static func openDawnAgentIfNeeded() {
        Task {
            await makeDefault().openDawnAgentIfNeeded()
        }
    }

    static func openDawnAgent() {
        Task {
            await makeDefault().openDawnAgent()
        }
    }

    func openDawnAgentIfNeeded() async {
        guard !isAgentRunning() else { return }
        await openDawnAgent()
    }

    func openDawnAgent() async {
        guard let agentAppURL else {
            logFailure(.missingBundle)
            return
        }

        do {
            try await opener.open(at: agentAppURL)
        } catch {
            logFailure(.openFailed(error.localizedDescription))
        }
    }

    private static func makeDefault() -> DawnAgentOpener {
        let agentAppURL = Bundle.main.bundleURL.appending(
            path: "Contents/Library/LoginItems/dawnAgent.app"
        )
        let resolvedURL = FileManager.default.fileExists(
            atPath: agentAppURL.path(percentEncoded: false)
        ) ? agentAppURL : nil

        return DawnAgentOpener(
            agentAppURL: resolvedURL,
            isAgentRunning: {
                !NSRunningApplication.runningApplications(
                    withBundleIdentifier: bundleIdentifier
                ).isEmpty
            },
            opener: EmbeddedDawnAgentProcessLauncher(),
            logFailure: log
        )
    }

    private static func log(_ failure: DawnAgentOpenFailure) {
        switch failure {
        case .missingBundle:
            #log(
                "Embedded dawnAgent was not found at Contents/Library/LoginItems/dawnAgent.app",
                level: .error,
                category: .appLifecycle
            )
        case let .openFailed(description):
            #log(
                "Failed to open dawnAgent: \(description, privacy: .public)",
                level: .error,
                category: .appLifecycle
            )
        }
    }
}

@MainActor
struct EmbeddedDawnAgentProcessLauncher: DawnAgentOpening {
    func open(at url: URL) async throws {
        let executableURL = url.appending(path: "Contents/MacOS/dawnAgent")
        guard FileManager.default.isExecutableFile(
            atPath: executableURL.path(percentEncoded: false)
        ) else {
            throw DawnAgentProcessLaunchError.missingExecutable
        }

        let process = Process()
        process.executableURL = executableURL
        try process.run()
    }
}

enum DawnAgentProcessLaunchError: Error {
    case missingExecutable
}
