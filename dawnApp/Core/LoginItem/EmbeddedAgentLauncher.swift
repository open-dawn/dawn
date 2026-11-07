import AppKit
import dawnLogging

enum EmbeddedAgentLaunchFailure: Equatable {
    case missingBundle
    case openFailed(String)
}

@MainActor
protocol EmbeddedAgentOpening {
    func launch(
        at url: URL,
        configuration: NSWorkspace.OpenConfiguration
    ) async throws
}

@MainActor
struct EmbeddedAgentLauncher {
    static let bundleIdentifier = "app.opendawn.dawnAgent"

    private let agentURL: URL?
    private let isAgentRunning: () -> Bool
    private let opener: any EmbeddedAgentOpening
    private let logFailure: (EmbeddedAgentLaunchFailure) -> Void

    init(
        agentURL: URL?,
        isAgentRunning: @escaping () -> Bool,
        opener: any EmbeddedAgentOpening,
        logFailure: @escaping (EmbeddedAgentLaunchFailure) -> Void = { _ in }
    ) {
        self.agentURL = agentURL
        self.isAgentRunning = isAgentRunning
        self.opener = opener
        self.logFailure = logFailure
    }

    static func launchIfNeeded() {
        let agentURL = Bundle.main.bundleURL.appending(
            path: "Contents/Library/LoginItems/dawnAgent.app"
        )
        let resolvedURL = FileManager.default.fileExists(
            atPath: agentURL.path(percentEncoded: false)
        ) ? agentURL : nil

        let launcher = EmbeddedAgentLauncher(
            agentURL: resolvedURL,
            isAgentRunning: {
                !NSRunningApplication.runningApplications(
                    withBundleIdentifier: bundleIdentifier
                ).isEmpty
            },
            opener: NSWorkspace.shared,
            logFailure: log
        )

        Task {
            await launcher.launchIfNeeded()
        }
    }

    func launchIfNeeded() async {
        guard !isAgentRunning() else { return }

        guard let agentURL else {
            logFailure(.missingBundle)
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false

        do {
            try await opener.launch(at: agentURL, configuration: configuration)
        } catch {
            logFailure(.openFailed(error.localizedDescription))
        }
    }

    private static func log(_ failure: EmbeddedAgentLaunchFailure) {
        switch failure {
        case .missingBundle:
            #log(
                "Embedded dawnAgent was not found at Contents/Library/LoginItems/dawnAgent.app",
                level: .error,
                category: .appLifecycle
            )
        case let .openFailed(description):
            #log(
                "Failed to open embedded dawnAgent: \(description, privacy: .public)",
                level: .error,
                category: .appLifecycle
            )
        }
    }
}

extension NSWorkspace: EmbeddedAgentOpening {
    @MainActor
    func launch(
        at url: URL,
        configuration: NSWorkspace.OpenConfiguration
    ) async throws {
        try await openApplication(at: url, configuration: configuration)
    }
}
