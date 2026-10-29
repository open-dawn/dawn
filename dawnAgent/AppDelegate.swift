import AppKit
import dawnLogging
import libdawn

typealias WorkspaceRuntimeFactory = @MainActor (EventBus) async throws -> WorkspaceRuntime
typealias MenuBarControllerFactory = @MainActor (WorkspaceRuntime) -> any MenuBarControlling

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let eventBusService: any EventBusServicing
    private let makeMenuBarController: MenuBarControllerFactory
    private let makeWorkspaceRuntime: WorkspaceRuntimeFactory

    private var menuBarController: (any MenuBarControlling)?
    private var workspaceRuntime: WorkspaceRuntime?
    private var windowManagerListener: WindowManagerListener?
    private var debugPingListener: DebugPingListener?
    private var startupTask: Task<Void, Never>?
    private var isStartingOrStarted = false

    private var isPreparingToTerminate = false

    init(
        eventBusService: any EventBusServicing = EventBusService(),
        makeMenuBarController: @escaping MenuBarControllerFactory = {
            MenuBarController(workspace: $0)
        },
        makeWorkspaceRuntime: @escaping WorkspaceRuntimeFactory = { bus in
            let publisher = EventBusContextSnapshotPublisher(bus: bus)

            let contextManager = try await ContextManager(snapshotPublisher: publisher)

            return WorkspaceRuntime(
                contextManager: contextManager,
            )
        }
    ) {
        self.eventBusService = eventBusService
        self.makeMenuBarController = makeMenuBarController
        self.makeWorkspaceRuntime = makeWorkspaceRuntime

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

        menuBarController?.stop()
        menuBarController = nil

        eventBusService.stop()

        windowManagerListener = nil
        debugPingListener = nil
        workspaceRuntime = nil
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isPreparingToTerminate, let workspaceRuntime, workspaceRuntime.activeContextID != nil else {
            return .terminateNow
        }

        isPreparingToTerminate = true

        Task { @MainActor in
            do {
                try await workspaceRuntime.stopActiveContext()
                sender.reply(toApplicationShouldTerminate: true)
            } catch {
                isPreparingToTerminate = false
                sender.reply(toApplicationShouldTerminate: false)
            }
        }

        return .terminateLater
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func start() async throws {
        guard !isStartingOrStarted else { return }
        isStartingOrStarted = true

        do {
            #log(
                "Creating workspace runtime",
                level: .info,
                category: .appLifecycle
            )

            let workspaceRuntime = try await makeWorkspaceRuntime(eventBusService.bus)

            await workspaceRuntime.refresh()

            try Task.checkCancellation()

            if workspaceRuntime.activeContextID != nil {
                try await workspaceRuntime.stopActiveContext()
            }

            try Task.checkCancellation()

            #log(
                "Workspace runtime created",
                level: .info,
                category: .appLifecycle
            )

            let windowManagerListener = WindowManagerListener(
                bus: eventBusService.bus,
                workspace: workspaceRuntime
            )

            let debugPingListener = DebugPingListener(bus: eventBusService.bus)

            let menuBarController = makeMenuBarController(workspaceRuntime)

            self.workspaceRuntime = workspaceRuntime
            self.windowManagerListener = windowManagerListener
            self.debugPingListener = debugPingListener
            self.menuBarController = menuBarController

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
