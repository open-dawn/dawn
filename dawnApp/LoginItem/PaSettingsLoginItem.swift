import PaLogging
import ServiceManagement

enum PaSettingsLoginItem {
    static let helperBundleIdentifier = "app.opendawn.PaWM"

    static func registerIfNeeded() {
        let service = SMAppService.loginItem(identifier: helperBundleIdentifier)

        #log("PaWM login-item status: \(service.status.rawValue)", level: .info, category: .appLifecycle)

        switch service.status {
        case .enabled:
            #log("PaWM login item is already enabled", level: .info, category: .appLifecycle)

        case .requiresApproval:
            #log("PaWM login item requires user approval", level: .warning, category: .appLifecycle)
        case .notRegistered, .notFound:
            do {
                #log("Registering PaWM login item", level: .info, category: .appLifecycle)

                try service.register()

                #log("PaWM login-item registration succeeded", level: .info, category: .appLifecycle)
            } catch {
                #log(
                    "PaWM login-item registration failed: \(error.localizedDescription,privacy: .public)",
                    level: .error,
                    category: .appLifecycle
                )
            }
        @unknown default:
            #log(
                "Unkown PaWM login-item status: \(service.status.rawValue)",
                level: .error,
                category: .appLifecycle
            )
        }
    }
}
