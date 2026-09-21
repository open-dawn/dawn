import AppKit

@MainActor
final class PaSettingsAppDelegate: NSObject, NSApplicationDelegate {
    let eventBusService = PaSettingsEventBusService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        PaSettingsLoginItem.registerIfNeeded()
        eventBusService.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventBusService.stop()
    }
}
