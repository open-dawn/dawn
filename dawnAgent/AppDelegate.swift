import AppKit
import dawnLogging
import libdawn

struct AgentRuntimeComponents {
    let workspace: WorkspaceRuntime
}

typealias AgentRuntimeFactory = @MainActor (EventBus, SettingsStore) async throws -> AgentRuntimeComponents
typealias MenuBarControllerFactory = @MainActor (WorkspaceRuntime, Bool) -> any MenuBarControlling
typealias ComponentIdentityLoader = @MainActor () throws -> ComponentIdentity

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let eventBusService: any EventBusServicing
    private let makeMenuBarController: MenuBarControllerFactory
    private let makeAgentRuntime: AgentRuntimeFactory
    private var menuBarController: (any MenuBarControlling)?
    private var workspaceRuntime: WorkspaceRuntime?
    private var windowManagerListener: WindowManagerListener?
    private var debugPingListener: DebugPingListener?
    private var accessibilityTrustListener: AccessibilityTrustListener?
    private var settingsListener: SettingsListener?
    private var startupTask: Task<Void, Never>?
    private var isStartingOrStarted = false

    private let lifecycle = AgentLifecycleState()
    private let loadComponentIdentity: ComponentIdentityLoader
    private var applicationUpdateListener: ApplicationUpdateListener?

    private var isPreparingToTerminate = false
    private var repository: any SettingsRepository

    init(
        eventBusService: any EventBusServicing = EventBusService(),
        repository: any SettingsRepository = UserDefaultsSettingsRepository(),
        makeMenuBarController: @escaping MenuBarControllerFactory = { workspace, isVisible in
            MenuBarController(workspace: workspace, initiallyVisible: isVisible)
        },
        makeAgentRuntime: @escaping AgentRuntimeFactory = AppDelegate.makeAgentRuntime,
        loadComponentIdentity: @escaping ComponentIdentityLoader = {
            try AgentComponentIdentity.load()
        }
    ) {
        self.eventBusService = eventBusService
        self.repository = repository
        self.makeMenuBarController = makeMenuBarController
        self.makeAgentRuntime = makeAgentRuntime
        self.loadComponentIdentity = loadComponentIdentity

        super.init()
    }

    private static func makeAgentRuntime(
        bus: EventBus,
        store: SettingsStore
    ) async throws -> AgentRuntimeComponents {
        let publisher = EventBusContextSnapshotPublisher(
            bus: bus
        )

        let contextManager = ContextManager(
            store: store,
            snapshotPublisher: publisher
        )

        return AgentRuntimeComponents(
            workspace: WorkspaceRuntime(
                contextManager: contextManager,
                snapshotPublisher: publisher
            )
        )
    }

    func applicationDidFinishLaunching(_: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        guard !AgentInstanceGuard.shouldTerminateCurrentInstance() else {
            #log(
                "Another dawnAgent is already running; quitting this instance",
                level: .info,
                category: .appLifecycle
            )
            NSApplication.shared.terminate(nil)
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

    func applicationWillTerminate(_: Notification) {
        startupTask?.cancel()
        startupTask = nil

        menuBarController?.stop()
        menuBarController = nil

        eventBusService.stop()

        windowManagerListener = nil
        debugPingListener = nil
        accessibilityTrustListener = nil
        settingsListener = nil
        workspaceRuntime = nil
        applicationUpdateListener = nil
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if isPreparingToTerminate {
            return .terminateLater
        }

        guard let workspaceRuntime, workspaceRuntime.activeContextID != nil else {
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

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }

    func start() async throws {
        guard !isStartingOrStarted else { return }
        isStartingOrStarted = true

        do {
            #log("Creating workspace runtime", level: .info, category: .appLifecycle)

            let componentIdentity = try loadComponentIdentity()

            let store = try await SettingsStore.make(repository: repository)
            let components = try await makeAgentRuntime(eventBusService.bus, store)

            let workspaceRuntime = components.workspace
            await workspaceRuntime.refresh()
            let settings = await store.generalSettings()
            try await reconcileRestoredActivity(in: workspaceRuntime)
            #log("Workspace runtime created", level: .info, category: .appLifecycle)

            let menuBarController = makeMenuBarController(workspaceRuntime, settings.showInMenuBar)
            let applicator = SettingsApplicator(menuBarController: menuBarController)
            await applicator.applySettings(settings)

            registerListeners(
                workspaceRuntime: workspaceRuntime,
                store: store,
                menuBarController: menuBarController,
                applicator: applicator,
                componentIdentity: componentIdentity
            )

            #log("Starting dawnAgent event bus", level: .info, category: .eventBus)
            eventBusService.start()

            #log("dawnAgent startup completed", level: .info, category: .appLifecycle)
        } catch {
            isStartingOrStarted = false
            throw error
        }
    }

    private func registerListeners(
        workspaceRuntime: WorkspaceRuntime,
        store: SettingsStore,
        menuBarController: any MenuBarControlling,
        applicator: any SettingsApplying,
        componentIdentity: ComponentIdentity
    ) {
        let windowManagerListener = WindowManagerListener(
            bus: eventBusService.bus,
            workspace: workspaceRuntime,
            lifecycle: lifecycle
        )

        let settingsListener = SettingsListener(
            bus: eventBusService.bus,
            settingsProvider: SettingsCoordinator(store: store),
            applicator: applicator,
            lifecycle: lifecycle
        )

        let debugPingListener = DebugPingListener(bus: eventBusService.bus)
        let accessibilityTrustListener = AccessibilityTrustListener(bus: eventBusService.bus)

        let updatePreparer = AgentUpdatePreparer(
            identity: componentIdentity,
            workspace: workspaceRuntime,
            lifecycle: lifecycle
        )

        let applicationUpdateListener = ApplicationUpdateListener(
            bus: eventBusService.bus,
            preparer: updatePreparer
        )

        self.workspaceRuntime = workspaceRuntime
        self.windowManagerListener = windowManagerListener
        self.debugPingListener = debugPingListener
        self.accessibilityTrustListener = accessibilityTrustListener
        self.settingsListener = settingsListener
        self.menuBarController = menuBarController
        self.applicationUpdateListener = applicationUpdateListener
    }

    private func reconcileRestoredActivity(in workspace: WorkspaceRuntime) async throws {
        try Task.checkCancellation()

        if workspace.activeContextID != nil {
            try await workspace.stopActiveContext()
        }

        try Task.checkCancellation()
    }
}
