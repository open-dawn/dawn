import dawnLogging
import libdawn
import ServiceManagement

enum SettingsLoginItem {
    static let helperBundleIdentifier = EventBusMachService.agentBundleIdentifier

    static func registerIfNeeded() {
        let service = SMAppService.loginItem(identifier: helperBundleIdentifier)

        #log(
            "dawnAgent login-item status: \(service.status.rawValue)",
            level: .info,
            category: .appLifecycle
        )

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

    static func apply(launchAtLogin: Bool) {
        guard launchAtLogin else { return }
        registerIfNeeded()
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
}
