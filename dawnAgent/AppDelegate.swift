import AppKit
import dawnLogging
import libdawn

struct AgentRuntimeComponents {
    let workspace: WorkspaceRuntime

    let menuBarVisibilityStore: any MenuBarVisibilityStoring
}

typealias AgentRuntimeFactory = @MainActor (EventBus) async throws -> AgentRuntimeComponents
typealias MenuBarControllerFactory = @MainActor (WorkspaceRuntime, Bool) -> any MenuBarControlling

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let eventBusService: any EventBusServicing
    private let makeMenuBarController: MenuBarControllerFactory
    private let makeAgentRuntime: AgentRuntimeFactory
    private var menuBarVisibilityListener: MenuBarVisibilityListener?

    private var menuBarController: (any MenuBarControlling)?
    private var workspaceRuntime: WorkspaceRuntime?
    private var windowManagerListener: WindowManagerListener?
    private var debugPingListener: DebugPingListener?
    private var startupTask: Task<Void, Never>?
    private var isStartingOrStarted = false

    private var isPreparingToTerminate = false

    init(
        eventBusService: any EventBusServicing = EventBusService(),
        makeMenuBarController: @escaping MenuBarControllerFactory = { workspace, isVisible in
            MenuBarController(workspace: workspace, initiallyVisible: isVisible)
        },
        makeAgentRuntime: @escaping AgentRuntimeFactory = { bus in
            let publisher = EventBusContextSnapshotPublisher(bus: bus)

            let contextManager = try await ContextManager(snapshotPublisher: publisher)

            return AgentRuntimeComponents(
                workspace: WorkspaceRuntime(contextManager: contextManager),
                menuBarVisibilityStore: contextManager.menuBarVisibilityStore
            )
        }
    ) {
        self.eventBusService = eventBusService
        self.makeMenuBarController = makeMenuBarController
        self.makeAgentRuntime = makeAgentRuntime

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
        menuBarVisibilityListener = nil
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

            let components = try await makeAgentRuntime(eventBusService.bus)

            let workspaceRuntime = components.workspace

            await workspaceRuntime.refresh()

            let initialMenuBarVisibility = await components.menuBarVisibilityStore.menuBarIsVisible()

            try await reconcileRestoredActivity(in: workspaceRuntime)

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

            let menuBarController = makeMenuBarController(workspaceRuntime, initialMenuBarVisibility)

            let menuBarVisibilityListener = MenuBarVisibilityListener(
                bus: eventBusService.bus,
                store: components.menuBarVisibilityStore,
                menuBarController: menuBarController
            )

            self.workspaceRuntime = workspaceRuntime
            self.windowManagerListener = windowManagerListener
            self.debugPingListener = debugPingListener
            self.menuBarController = menuBarController
            self.menuBarVisibilityListener = menuBarVisibilityListener

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

    private func reconcileRestoredActivity(in workspace: WorkspaceRuntime) async throws {
        try Task.checkCancellation()

        if workspace.activeContextID != nil {
            try await workspace.stopActiveContext()
        }

        try Task.checkCancellation()
    }
}
