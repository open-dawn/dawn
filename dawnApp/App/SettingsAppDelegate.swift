import AppKit
import dawnLogging

@MainActor
final class SettingsAppDelegate: NSObject, NSApplicationDelegate {
    let eventBusService: SettingsEventBusService
    let contextStore: SettingsContextStore
    let settingsStore: SettingsViewStore
    let updaterService: AppUpdaterService
    let accessibilityPermissionService: AccessibilityPermissionService

    private let componentCoordinator: any UpdateComponentCoordinating
    private var startupReconciliationTask: Task<Void, Never>?

    override init() {
        let eventBusService = SettingsEventBusService()
        let updateClient = SparkleUpdateClient()

        let updateComponents: [any UpdateComponent]

        #if DEBUG
        updateComponents = []
        #else
        updateComponents = [
            DawnAgentUpdateComponent(
                eventRequester: eventBusService.bus,
                connectionWaiter: eventBusService,
                service: DawnAgentServiceController()
            )
        ]
        #endif

        let componentCoordinator = UpdateComponentCoordinator(
            components: updateComponents,
            journalStore: FileUpdateRecoveryJournalStore(),
            sourceBuildProvider: {
                try ApplicationBuild.load()
            }
        )

        self.eventBusService = eventBusService
        self.componentCoordinator = componentCoordinator

        contextStore = SettingsContextStore(bus: eventBusService.bus)

        settingsStore = SettingsViewStore(bus: eventBusService.bus)

        updaterService = AppUpdaterService(client: updateClient, componentCoordinator: componentCoordinator)

        accessibilityPermissionService = AccessibilityPermissionService(bus: eventBusService.bus)

        super.init()
    }

    func applicationDidFinishLaunching(_: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        contextStore.start()
        settingsStore.start()
        eventBusService.start()
        updaterService.start()

        startupReconciliationTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                let expectedBuild = try ApplicationBuild.load()

                try await componentCoordinator.reconcileAfterUpdate(expectedBuild: expectedBuild)
            } catch is CancellationError {
                return
            } catch {
                let description = String(describing: error)

                #log(
                 "Failed to reconcile installed components: \(description, privacy: .private)",
                 level: .error,
                 category: .appLifecycle
                )
            }
        }
    }

    func applicationWillTerminate(_: Notification) {
        startupReconciliationTask?.cancel()
        startupReconciliationTask = nil

        contextStore.stop()
        settingsStore.stop()
        eventBusService.stop()
    }
}
