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
}
