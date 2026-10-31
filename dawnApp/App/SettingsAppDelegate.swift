import AppKit

@MainActor
final class SettingsAppDelegate: NSObject, NSApplicationDelegate {
    let eventBusService: SettingsEventBusService
    let contextStore: SettingsContextStore
    let settingsStore: SettingsViewStore

    override init() {
        let eventBusService = SettingsEventBusService()

        self.eventBusService = eventBusService
        contextStore = SettingsContextStore(bus: eventBusService.bus)
        settingsStore = SettingsViewStore(bus: eventBusService.bus)

        super.init()
    }

    func applicationDidFinishLaunching(_: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        contextStore.start()
        settingsStore.start()
        eventBusService.start()
        SettingsLoginItem.registerIfNeeded()
    }

    func applicationWillTerminate(_: Notification) {
        contextStore.stop()
        settingsStore.stop()
        eventBusService.stop()
    }
}
