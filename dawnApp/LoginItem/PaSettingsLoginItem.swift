import dawnLogging
import ServiceManagement

enum PaSettingsLoginItem {
    static let helperBundleIdentifier = "app.opendawn.dawnAgent"

    static func registerIfNeeded() {
        let service = SMAppService.loginItem(identifier: helperBundleIdentifier)

        #log("dawnAgent login-item status: \(service.status.rawValue)", level: .info, category: .appLifecycle)

        switch service.status {
        case .enabled:
            #log("dawnAgent login item is already enabled", level: .info, category: .appLifecycle)

        case .requiresApproval:
            #log("dawnAgent login item requires user approval", level: .warning, category: .appLifecycle)
        case .notRegistered, .notFound:
            do {
                #log("Registering dawnAgent login item", level: .info, category: .appLifecycle)

                try service.register()

                #log("dawnAgent login-item registration succeeded", level: .info, category: .appLifecycle)
            } catch {
                #log(
                    "dawnAgent login-item registration failed: \(error.localizedDescription,privacy: .public)",
                    level: .error,
                    category: .appLifecycle
                )
            }
        @unknown default:
            #log(
                "Unkown dawnAgent login-item status: \(service.status.rawValue)",
                level: .error,
                category: .appLifecycle
            )
        }
    }
}
