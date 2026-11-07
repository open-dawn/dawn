import dawnLogging
import libdawn
import ServiceManagement

enum SettingsLoginItem {
    static let helperBundleIdentifier = EventBusMachService.agentBundleIdentifier

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
