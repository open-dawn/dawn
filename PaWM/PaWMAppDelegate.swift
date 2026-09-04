import AppKit

@MainActor
final class PaWMAppDelegate: NSObject, NSApplicationDelegate {
    private let eventBusService = PaWMEventBusService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        eventBusService.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventBusService.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
