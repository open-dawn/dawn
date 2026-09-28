import AppKit
import libdawn
import dawnLogging

typealias WindowManagerListenerFactory = @MainActor (PaEventBus) async throws -> WindowManagerListener

@MainActor
final class dawnAgentAppDelegate: NSObject, NSApplicationDelegate {
    private let eventBusService: any dawnAgentEventBusServicing
    private let makeWindowManagerListener: WindowManagerListenerFactory
    private var windowManagerListener: WindowManagerListener?
    private var debugPingListener: dawnAgentDebugPingListener?
    private var startupTask: Task<Void, Never>?
    private var isStartingOrStarted = false

    init(
        eventBusService: any dawnAgentEventBusServicing = dawnAgentEventBusService(),
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

        #log(
            "dawnAgent application finished launching",
            level: .info,
            category: .appLifecycle
        )

        startupTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                try await start()
            } catch is CancellationError {
                // Expected when dawnAgent terminates during startup
            } catch {
                #log("Failed to start dawnAgent: \(error)", level: .critical, category: .appLifecycle)
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
            #log(
                "Creating WindowManager listener",
                level: .info,
                category: .appLifecycle
            )

            let windowManagerListener = try await makeWindowManagerListener(
                eventBusService.bus
            )

            try Task.checkCancellation()

            #log(
                "WindowManager listener created",
                level: .info,
                category: .appLifecycle
            )

            self.windowManagerListener = windowManagerListener
            self.debugPingListener = dawnAgentDebugPingListener(
                bus: eventBusService.bus
            )

            #log(
                "Starting dawnAgent event bus",
                level: .info,
                category: .eventBus
            )

            eventBusService.start()

            #log(
                "dawnAgent startup completed",
                level: .info,
                category: .appLifecycle
            )
        } catch {
            isStartingOrStarted = false
            throw error
        }
    }
}
