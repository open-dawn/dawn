import AppKit

@MainActor
final class SettingsAppDelegate: NSObject, NSApplicationDelegate {
    let eventBusService: SettingsEventBusService
    let contextStore: SettingsContextStore

    override init() {
        let eventBusService = SettingsEventBusService()

        self.eventBusService = eventBusService
        self.contextStore = SettingsContextStore(
            bus: eventBusService.bus
        )

        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        contextStore.start()
        eventBusService.start()
        SettingsLoginItem.registerIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        contextStore.stop()
        eventBusService.stop()
    }
}
