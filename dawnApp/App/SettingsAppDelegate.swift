import AppKit

@MainActor
final class SettingsAppDelegate: NSObject, NSApplicationDelegate {
    let eventBusService: SettingsEventBusService
    let contextStore: SettingsContextStore
    let updaterService: AppUpdaterService
    let accessibilityPermissionService: AccessibilityPermissionService

    override init() {
        let eventBusService = SettingsEventBusService()
        let updateClient = SparkleUpdateClient()

        self.eventBusService = eventBusService
        contextStore = SettingsContextStore(
            bus: eventBusService.bus
        )
        updaterService = AppUpdaterService(client: updateClient)
        accessibilityPermissionService = AccessibilityPermissionService(
            bus: eventBusService.bus
        )

        super.init()
    }

    func applicationDidFinishLaunching(_: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        contextStore.start()
        eventBusService.start()
        updaterService.start()
        SettingsLoginItem.registerIfNeeded()
    }

    func applicationWillTerminate(_: Notification) {
        contextStore.stop()
        eventBusService.stop()
    }
}
