import AppKit
import dawnLogging
import libdawn
import ServiceManagement

enum SettingsLoginItem {
    static let helperBundleIdentifier = EventBusMachService.agentBundleIdentifier

    /// Makes sure the login item is registered and the agent process is running.
    ///
    /// A clean dawnAgent quit leaves `SMAppService` enabled, and launchd will
    /// not restart a helper that exited with status 0 until the next login.
    /// When the agent is missing but still registered, unregister then register
    /// so the helper starts immediately for this DAWN session.
    static func ensureRunning(
        isAgentRunning: () -> Bool = {
            !NSRunningApplication.runningApplications(
                withBundleIdentifier: helperBundleIdentifier
            ).isEmpty
        }
    ) {
        let service = SMAppService.loginItem(identifier: helperBundleIdentifier)
        let action = AgentLoginItemAction.resolve(
            isAgentRunning: isAgentRunning(),
            status: service.status
        )

        #log(
            """
            dawnAgent login-item status: \(service.status.rawValue); \
            action: \(String(describing: action), privacy: .public)
            """,
            level: .info,
            category: .appLifecycle
        )

        switch action {
        case .ensureRegistered:
            register(service)

        case .register:
            register(service)

        case .waitForApproval:
            return

        case .bounce:
            bounce(service)
        }
    }

    static func apply(launchAtLogin: Bool) {
        guard launchAtLogin else { return }
        ensureRunning()
    }

    static func applyForTermination(launchAtLogin: Bool) {
        guard !launchAtLogin else { return }

        let service = SMAppService.loginItem(identifier: helperBundleIdentifier)

        guard service.status == .enabled else { return }

        do {
            try service.unregister()
            #log(
                "Unregistered dawnAgent login item because launch at login is off",
                level: .info,
                category: .appLifecycle
            )
        } catch {
            #log(
                "dawnAgent login-item unregister failed: \(error.localizedDescription, privacy: .public)",
                level: .error,
                category: .appLifecycle
            )
        }
    }

    private static func register(_ service: SMAppService) {
        switch service.status {
        case .enabled, .requiresApproval:
            return
        case .notRegistered, .notFound:
            break
        @unknown default:
            break
        }

        do {
            try service.register()
            #log(
                "Registered dawnAgent login item for the event bus",
                level: .info,
                category: .appLifecycle
            )
        } catch {
            #log(
                "dawnAgent login-item registration failed: \(error.localizedDescription, privacy: .public)",
                level: .error,
                category: .appLifecycle
            )
        }
    }

    private static func bounce(_ service: SMAppService) {
        #log(
            "Bouncing dawnAgent login item because the helper is registered but not running",
            level: .info,
            category: .appLifecycle
        )

        service.unregister { error in
            if let error {
                #log(
                    """
                    dawnAgent login-item unregister before relaunch failed: \
                    \(error.localizedDescription, privacy: .public)
                    """,
                    level: .error,
                    category: .appLifecycle
                )
            }

            DispatchQueue.main.async {
                register(
                    SMAppService.loginItem(identifier: helperBundleIdentifier)
                )
            }
        }
    }
}

enum AgentLoginItemAction: Equatable {
    case ensureRegistered
    case register
    case bounce
    case waitForApproval

    static func resolve(
        isAgentRunning: Bool,
        status: SMAppService.Status
    ) -> AgentLoginItemAction {
        if isAgentRunning {
            return .ensureRegistered
        }

        switch status {
        case .enabled:
            return .bounce
        case .requiresApproval:
            return .waitForApproval
        case .notRegistered, .notFound:
            return .register
        @unknown default:
            return .register
        }
    }
}
