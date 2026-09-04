import AppKit

@MainActor
final class PaWMAppDelegate: NSObject, NSApplicationDelegate {
    private let eventBusService = PaWMEventBusService()
    private var debugPing: PaWMDebugPingListener?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        eventBusService.start()
        debugPing = PaWMDebugPingListener(bus: eventBusService.bus)
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventBusService.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
