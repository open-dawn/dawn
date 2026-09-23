import ServiceManagement

enum PaSettingsLoginItem {
    static let helperBundleIdentifier = "app.opendawn.PaWM"

    static func registerIfNeeded() {
        let service = SMAppService.loginItem(identifier: helperBundleIdentifier)

        switch service.status {
        case .enabled, .requiresApproval:
            return
        case .notRegistered, .notFound:
            try? service.register()
        @unknown default:
            try? service.register()
        }
    }
}
