import AppKit

@MainActor
final class SettingsAppDelegate: NSObject, NSApplicationDelegate {
    let eventBusService: SettingsEventBusService
    let contextStore: SettingsContextStore
    let settingsStore: SettingsViewStore
    let updaterService: AppUpdaterService
    let accessibilityPermissionService: AccessibilityPermissionService

    override init() {
        let eventBusService = SettingsEventBusService()
        let updateClient = SparkleUpdateClient()

        self.eventBusService = eventBusService
        contextStore = SettingsContextStore(bus: eventBusService.bus)
        settingsStore = SettingsViewStore(bus: eventBusService.bus)
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
        settingsStore.start()
        SettingsLoginItem.ensureRunning()
        eventBusService.start()
        updaterService.start()
    }

    func applicationWillTerminate(_: Notification) {
        SettingsLoginItem.applyForTermination(
            launchAtLogin: settingsStore.settings.launchAtLogin
        )
        contextStore.stop()
        settingsStore.stop()
        eventBusService.stop()
    }
}
