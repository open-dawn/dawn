import AppKit

@MainActor
final class PaSettingsAppDelegate: NSObject, NSApplicationDelegate {
    let eventBusService: PaSettingsEventBusService
    let contextStore: PaSettingsContextStore

    override init() {
        let eventBusService = PaSettingsEventBusService()

        self.eventBusService = eventBusService
        self.contextStore = PaSettingsContextStore(
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
        PaSettingsLoginItem.registerIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        contextStore.stop()
        eventBusService.stop()
    }
}
