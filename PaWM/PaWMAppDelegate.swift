import AppKit
import PaLogging
import PaEventKit

typealias WindowManagerListenerFactory = @MainActor (PaEventBus) async throws -> WindowManagerListener

@MainActor
final class PaWMAppDelegate: NSObject, NSApplicationDelegate {
    private let eventBusService: any PaWMEventBusServicing
    private let makeWindowManagerListener: WindowManagerListenerFactory
    private var windowManagerListener: WindowManagerListener?
    private var debugPingListener: PaWMDebugPingListener?
    private var startupTask: Task<Void, Never>?
    private var isStartingOrStarted = false

    init(
        eventBusService: any PaWMEventBusServicing = PaWMEventBusService(),
        makeWindowManagerListener: @escaping WindowManagerListenerFactory = { bus in
            try await WindowManagerListener(bus: bus)
        }
    ) {
        self.eventBusService = eventBusService
        self.makeWindowManagerListener = makeWindowManagerListener
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        startupTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                try await start()
            } catch is CancellationError {
                // Expected when PaWM terminates during startup
            } catch {
                #log("Failed to start PaWM: \(error)", level: .critical, category: .appLifecycle)
                NSApplication.shared.terminate(nil)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        startupTask?.cancel()
        startupTask = nil

        eventBusService.stop()

        windowManagerListener = nil
        debugPingListener = nil
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func start() async throws {
        guard !isStartingOrStarted else { return }
        isStartingOrStarted = true

        do {
            let windowManagerListener = try await makeWindowManagerListener(
                eventBusService.bus
            )

            try Task.checkCancellation()

            self.windowManagerListener = windowManagerListener
            self.debugPingListener = PaWMDebugPingListener(
                bus: eventBusService.bus
            )

            eventBusService.start()
        } catch {
            isStartingOrStarted = false
            throw error
        }
    }
}
