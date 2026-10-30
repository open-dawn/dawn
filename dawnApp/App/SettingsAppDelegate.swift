import AppKit

@MainActor
final class SettingsAppDelegate: NSObject, NSApplicationDelegate {
    let eventBusService: SettingsEventBusService
    let contextStore: SettingsContextStore
    let updaterService: AppUpdaterService

    override init() {
        let eventBusService = SettingsEventBusService()
        let updateClient = SparkleUpdateClient()

        self.eventBusService = eventBusService
        self.contextStore = SettingsContextStore(
            bus: eventBusService.bus
        )
        self.updaterService = AppUpdaterService(client: updateClient)

        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        contextStore.start()
        eventBusService.start()
        updaterService.start()
        SettingsLoginItem.registerIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        contextStore.stop()
        eventBusService.stop()
    }
}
