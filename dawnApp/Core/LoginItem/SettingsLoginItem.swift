import dawnLogging
import libdawn
import ServiceManagement

enum SettingsLoginItem {
    static let helperBundleIdentifier = EventBusMachService.agentBundleIdentifier

    static func clearRegistration() {
        let service = SMAppService.loginItem(identifier: helperBundleIdentifier)

        #log(
            "dawnAgent login-item status before clear: \(service.status.rawValue)",
            level: .info,
            category: .appLifecycle
        )

        switch service.status {
        case .notRegistered, .notFound:
            return
        case .enabled, .requiresApproval:
            break
        @unknown default:
            break
        }

        do {
            try service.unregister()
            #log(
                "Cleared dawnAgent login-item registration so a process-launched agent can own the Mach service",
                level: .info,
                category: .appLifecycle
            )
        } catch {
            #log(
                "dawnAgent login-item clear failed: \(error.localizedDescription, privacy: .public)",
                level: .error,
                category: .appLifecycle
            )
        }
    }

    static func apply(launchAtLogin: Bool) {
        let service = SMAppService.loginItem(identifier: helperBundleIdentifier)

        #log(
            "dawnAgent login-item status: \(service.status.rawValue)",
            level: .info,
            category: .appLifecycle
        )

        do {
            if launchAtLogin {
                switch service.status {
                case .enabled, .requiresApproval:
                    return
                case .notRegistered, .notFound:
                    try service.register()
                @unknown default:
                    try service.register()
                }
            } else if service.status == .enabled {
                try service.unregister()
            }
        } catch {
            #log(
                "dawnAgent login-item update failed: \(error.localizedDescription, privacy: .public)",
                level: .error,
                category: .appLifecycle
            )
        }
    }
}
