//
//  AppDelegateTests.swift
//  dawn
//
//  Created by Rafael Venetikides on 21/09/26.
//

import AppKit
import Testing
import libdawn

@testable import dawnAgent

@MainActor
@Suite("AppDelegate")
struct AppDelegateTests {
    @Test("Start registers and retains listeners before starting service")
    func startRegistersListenersBeforeService() async throws {
        let service = EventBusServiceSpy()
        let provider = WorkspaceProviderStub()
        let menuBarController = MenuBarControllerSpy()
        let identity = ComponentIdentity(
            identifier: EventBusMachService.agentBundleIdentifier,
            version: "1.2.0",
            build: "42"
        )

        let delegate = AppDelegate(
            eventBusService: service,
            repository: MockSettingsRepository(),
            makeMenuBarController: { _, _ in
                menuBarController
            },
            makeAgentRuntime: { _, _ in
                makeAgentRuntimeComponents(
                    provider: provider
                )
            },
            loadComponentIdentity: {
                identity
            }
        )

        try await delegate.start()

        #expect(service.startCallCount == 1)
        #expect(service.listenersWereRegisteredWhenStarted)

        #expect(service.bus.hasListeners(for: .getWorkspaces(GetWorkspacesEvent())))
        #expect(service.bus.hasListeners(for: .debugPing(DebugPingEvent())))
        #expect(service.bus.hasListeners(for: .getSettings(GetSettingsEvent())))
        #expect(service.bus.hasListeners(for: .getComponentIdentity(GetComponentIdentityEvent())))
        #expect(service.bus.hasListeners(for: .prepareForApplicationUpdate(PrepareForApplicationUpdateEvent())))
    }

    @Test("Retained workspace listener answers workspace requests")
    func retainedListenerAnswersWorkspaceRequests() async throws {
        let expectedWorkspace = [
            Workspace(
                name: "Study",
                symbol: "book"
            )
        ]

        let service = EventBusServiceSpy()
        let provider = WorkspaceProviderStub(workspaces: expectedWorkspace)
        let menuBarController = MenuBarControllerSpy()

        let delegate = AppDelegate(
            eventBusService: service,
            repository: MockSettingsRepository(),
            makeMenuBarController: { _, _ in
                menuBarController
            },
            makeAgentRuntime: { _, _ in
                makeAgentRuntimeComponents(
                    provider: provider
                )
            }
        )

        try await delegate.start()

        let response = try await service.bus.ask(
            .getWorkspaces(GetWorkspacesEvent()),
            timeout: .seconds(1)
        )

        guard case .workspacesFetched(let workspacesFetchedEvent) = response else {
            Issue.record("Expected workspacesFetched, received \(response)")
            return
        }

        #expect(workspacesFetchedEvent.workspaces == expectedWorkspace)
    }

    @Test("Startup failure does not start event bus service")
    func startupFailureDoesNotStartService() async {
        let service = EventBusServiceSpy()
        let menuBarController = MenuBarControllerSpy()

        let delegate = AppDelegate(
            eventBusService: service,
            repository: MockSettingsRepository(),
            makeMenuBarController: { _, _ in
                menuBarController
            },
            makeAgentRuntime: { _, _ in
                throw StartupError.expected
            }
        )

        await #expect(throws: StartupError.expected) {
            try await delegate.start()
        }

        #expect(service.startCallCount == 0)
        #expect(!service.bus.hasListeners(for: .debugPing(DebugPingEvent())))
    }

    @Test("Termination stops service and releases listeners")
    func terminationStopsServiceAndReleasesListeners() async throws {
        let service = EventBusServiceSpy()
        let provider = WorkspaceProviderStub()
        let menuBarController = MenuBarControllerSpy()

        let delegate = AppDelegate(
            eventBusService: service,
            repository: MockSettingsRepository(),
            makeMenuBarController: { _, _ in
                menuBarController
            },
            makeAgentRuntime: { _, _ in
                makeAgentRuntimeComponents(
                    provider: provider
                )
            }
        )

        try await delegate.start()

        delegate.applicationWillTerminate(
            Notification(
                name: NSApplication.willTerminateNotification
            )
        )

        #expect(service.stopCallCount == 1)
        #expect(!service.bus.hasListeners(for: .getWorkspaces(GetWorkspacesEvent())))
        #expect(!service.bus.hasListeners(for: .debugPing(DebugPingEvent())))
        #expect(!service.bus.hasListeners(for: .getSettings(GetSettingsEvent())))
        #expect(!service.bus.hasListeners(for: .applySettings(ApplySettingsEvent())))
        #expect(menuBarController.stopCallCount == 1)
    }

    @Test("Repeated starts initialize only once")
    func repeatedStartsInitializeOnlyOnce() async throws {
        let service = EventBusServiceSpy()
        let provider = WorkspaceProviderStub()
        var factoryCallCount = 0
        let menuBarController = MenuBarControllerSpy()

        let delegate = AppDelegate(
            eventBusService: service,
            repository: MockSettingsRepository(),
            makeMenuBarController: { _, _ in
                menuBarController
            },
            makeAgentRuntime: { _, _ in
                factoryCallCount += 1

                return makeAgentRuntimeComponents(
                    provider: provider
                )
            }
        )

        try await delegate.start()
        try await delegate.start()

        #expect(factoryCallCount == 1)
        #expect(service.startCallCount == 1)
    }

    @Test("Overlapping starts initialize only once")
    func overlappingStartsInitializeOnlyOnce() async throws {
        let service = EventBusServiceSpy()
        let provider = WorkspaceProviderStub()
        let factory = PausingWorkspaceRuntimeFactory(provider: provider)
        let menuBarController = MenuBarControllerSpy()
        let delegate = AppDelegate(
            eventBusService: service,
            repository: MockSettingsRepository(),
            makeMenuBarController: { _, _ in
                menuBarController
            },
            makeAgentRuntime: { _, _ in
                AgentRuntimeComponents(
                    workspace: await factory.makeRuntime()
                )
            }
        )

        let firstStart = Task { @MainActor in
            try await delegate.start()
        }

        await factory.waitUntilCalled()

        let secondStart = Task { @MainActor in
            try await delegate.start()
        }

        try await secondStart.value

        #expect(factory.callCount == 1)
        #expect(service.startCallCount == 0)

        factory.resume()
        try await firstStart.value

        #expect(factory.callCount == 1)
        #expect(service.startCallCount == 1)
    }

    @Test("Startup can be retried after failure")
    func startupCanBeRetriedAfterFailure() async throws {
        let service = EventBusServiceSpy()
        let provider = WorkspaceProviderStub()
        var attemptCount = 0
        let menuBarController = MenuBarControllerSpy()

        let delegate = AppDelegate(
            eventBusService: service,
            repository: MockSettingsRepository(),
            makeMenuBarController: { _, _ in
                menuBarController
            },
            makeAgentRuntime: { _, _ in
                attemptCount += 1

                if attemptCount == 1 {
                    throw StartupError.expected
                }

                return makeAgentRuntimeComponents(
                    provider: provider
                )
            }
        )

        await #expect(throws: StartupError.expected) {
            try await delegate.start()
        }

        try await delegate.start()

        #expect(attemptCount == 2)
        #expect(service.startCallCount == 1)
    }

    @Test("Start loads initial workspace snapshot")
    func startLoadsInitialWorkspaceSnapshot() async throws {
        let service = EventBusServiceSpy()

        let expectedWorkspaces = [
            Workspace(
                name: "Study",
                symbol: "book"
            )
        ]

        let provider = WorkspaceProviderStub(
            workspaces: expectedWorkspaces
        )

        let runtime = WorkspaceRuntime(
            workspaceCatalog: provider
        )

        let menuBarController = MenuBarControllerSpy()

        let delegate = AppDelegate(
            eventBusService: service,
            repository: MockSettingsRepository(),
            makeMenuBarController: { _, _ in
                menuBarController
            },
            makeAgentRuntime: { _, _ in
                AgentRuntimeComponents(
                    workspace: runtime
                )
            }
        )

        try await delegate.start()

        #expect(provider.getWorkspaceSnapshotCallCount == 1)
        #expect(runtime.workspaces == expectedWorkspaces)
        #expect(provider.stopActiveWorkspaceCallCount == 0)
    }

    @Test("Start creates menu controller with shared runtime once")
    func startCreatesMenuControllerOnce() async throws {
        let service = EventBusService()
        let provider = WorkspaceProviderStub()

        let runtime = WorkspaceRuntime(
            workspaceCatalog: provider
        )

        let menuBarController = MenuBarControllerSpy()

        var factoryCallCount = 0
        var receivedWorkspace: WorkspaceRuntime?

        let delegate = AppDelegate(
            eventBusService: service,
            repository: MockSettingsRepository(),
            makeMenuBarController: { workspace, _ in
                factoryCallCount += 1
                receivedWorkspace = workspace
                return menuBarController
            },
            makeAgentRuntime: { _, _ in
                AgentRuntimeComponents(
                    workspace: runtime
                )
            }
        )

        try await delegate.start()

        let injectedWorkspace = try #require(receivedWorkspace)

        #expect(factoryCallCount == 1)
        #expect(injectedWorkspace === runtime)
    }

    @Test("Start ends a restored active session before creating menu bar")
    func startEndsRestoredActiveSession() async throws {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )

        let provider = WorkspaceProviderStub(
            workspaces: [workspace]
        )

        provider.workspaceActivity.activate(
            workspaceID: workspace.id,
            at: Date(timeIntervalSince1970: 100)
        )

        let runtime = WorkspaceRuntime(
            workspaceCatalog: provider
        )

        let service = EventBusServiceSpy()
        let menuBarController = MenuBarControllerSpy()

        var activeWorkspaceReceivedByMenuBar: UUID?

        let delegate = AppDelegate(
            eventBusService: service,
            repository: MockSettingsRepository(),
            makeMenuBarController: { workspace, _ in
                activeWorkspaceReceivedByMenuBar =
                    workspace.activeWorkspaceID

                return menuBarController
            },
            makeAgentRuntime: { _, _ in
                AgentRuntimeComponents(
                    workspace: runtime
                )
            }
        )

        try await delegate.start()

        #expect(provider.stopActiveWorkspaceCallCount == 1)
        #expect(provider.workspaceActivity.activeWorkspaceID == nil)
        #expect(runtime.activeWorkspaceID == nil)
        #expect(activeWorkspaceReceivedByMenuBar == nil)

        #expect(
            runtime.lastActiveAt(for: workspace.id)
                == provider.lastStopDate
        )
    }

    @Test(
        "Start restores persisted menu bar visibility",
        arguments: [true, false]
    )
    func startRestoresMenuBarVisibility(
        expectedVisibility: Bool
    ) async throws {
        let service = EventBusServiceSpy()
        let provider = WorkspaceProviderStub()
        var document = SettingsDocument.empty
        document.generalSettings.showInMenuBar = expectedVisibility

        let menuBarController = MenuBarControllerSpy()

        var receivedVisibility: Bool?

        let delegate = AppDelegate(
            eventBusService: service,
            repository: MockSettingsRepository(document: document),
            makeMenuBarController: { _, isVisible in
                receivedVisibility = isVisible
                return menuBarController
            },
            makeAgentRuntime: { _, _ in
                makeAgentRuntimeComponents(provider: provider)
            }
        )

        try await delegate.start()

        #expect(receivedVisibility == expectedVisibility)
        #expect(menuBarController.isVisible == expectedVisibility)
    }

    @Test("Retained update listener reports component identity")
    func retainedUpdateListenerReportsIdentity() async throws {
        let expectedIdentity = ComponentIdentity(
            identifier: EventBusMachService.agentBundleIdentifier,
            version: "1.2.0",
            build: "42"
        )

        let service = EventBusServiceSpy()
        let provider = WorkspaceProviderStub()
        let menuBarController = MenuBarControllerSpy()

        let delegate = AppDelegate(
            eventBusService: service,
            repository: MockSettingsRepository(),
            makeMenuBarController: { _, _ in
                menuBarController
            },
            makeAgentRuntime: { _, _ in
                makeAgentRuntimeComponents(provider: provider)
            },
            loadComponentIdentity: {
                expectedIdentity
            }
        )

        try await delegate.start()

        let response = try await service.bus.ask(
            .getComponentIdentity(
                GetComponentIdentityEvent()
            ),
            timeout: .seconds(1)
        )

        #expect(
            response == .componentIdentity(
                ComponentIdentityEvent(
                    identity: expectedIdentity
                )
            )
        )
    }
}

@MainActor
private final class EventBusServiceSpy: EventBusServicing {
    let bus = EventBus()

    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var listenersWereRegisteredWhenStarted = false

    func start() {
        startCallCount += 1

        let hasWorkspaceListener = bus.hasListeners(
            for: .getWorkspaces(
                GetWorkspacesEvent()
            )
        )

        let hasDebugListener = bus.hasListeners(
            for: .debugPing(
                DebugPingEvent()
            )
        )

        let hasSettingsListener = bus.hasListeners(
            for: .getSettings(GetSettingsEvent())
        )

        let hasApplySettingsListener = bus.hasListeners(
            for: .applySettings(ApplySettingsEvent())
        )

        let hasComponentIdentityListener = bus.hasListeners(
            for: .getComponentIdentity(GetComponentIdentityEvent())
        )

        let hasUpdatePreparationListener = bus.hasListeners(
            for: .prepareForApplicationUpdate(PrepareForApplicationUpdateEvent())
        )

        listenersWereRegisteredWhenStarted =
            hasWorkspaceListener
            && hasDebugListener
            && hasSettingsListener
            && hasApplySettingsListener
            && hasComponentIdentityListener
            && hasUpdatePreparationListener
    }

    func stop() {
        stopCallCount += 1
    }
}

@MainActor
private final class WorkspaceProviderStub: WorkspaceManaging {
    private(set) var getWorkspaceSnapshotCallCount = 0
    private(set) var stopActiveWorkspaceCallCount = 0
    private(set) var lastStopDate: Date?

    private let workspaces: [Workspace]

    var workspaceActivity: WorkspaceActivityState = .empty

    func createWorkspace(
        name: String,
        symbol: String,
        applications: [WorkspaceApplication],
        transition: WorkspaceTransition
    ) async throws -> Workspace {
        Workspace(
            name: name,
            symbol: symbol,
            applications: applications,
            transition: transition
        )
    }

    func updateWorkspace(_ workspace: Workspace) async throws {
    }

    func deleteWorkspace(id: UUID) async throws {
    }

    func archiveWorkspace(id: UUID) async throws {
    }

    func unarchiveWorkspace(id: UUID) async throws {
    }

    func getWorkspace(id: UUID) async -> Workspace? {
        Workspace(id: id, name: "Placeholder", symbol: "book")
    }

    init(workspaces: [Workspace] = []) {
        self.workspaces = workspaces
    }

    func getAvailableWorkspaces() async -> [Workspace] {
        return workspaces
    }

    func getWorkspaceActivity() async -> WorkspaceActivityState {
        workspaceActivity
    }

    func recordWorkspaceActivation(workspaceID: UUID, at date: Date) async throws -> WorkspaceActivityState {
        guard workspaces.contains(where: { $0.id == workspaceID }) else {
            throw SettingsStoreError.workspaceNotFound(workspaceID)
        }

        workspaceActivity.activate(
            workspaceID: workspaceID,
            at: date
        )

        return workspaceActivity
    }

    func stopActiveWorkspace(at date: Date) async throws -> WorkspaceActivityState {
        stopActiveWorkspaceCallCount += 1
        lastStopDate = date

        workspaceActivity.stop(at: date)

        return workspaceActivity
    }

    func getWorkspaceSnapshot() async -> WorkspaceSnapshot {
        getWorkspaceSnapshotCallCount += 1

        return WorkspaceSnapshot(
            workspaces: workspaces,
            activity: workspaceActivity
        )
    }
}

@MainActor
private final class PausingWorkspaceRuntimeFactory {
    private let provider: WorkspaceProviderStub
    private var callWaiter: CheckedContinuation<Void, Never>?
    private var factoryContinuation: CheckedContinuation<Void, Never>?

    private(set) var callCount = 0

    init(provider: WorkspaceProviderStub) {
        self.provider = provider
    }

    func makeRuntime() async -> WorkspaceRuntime {
        callCount += 1

        callWaiter?.resume()
        callWaiter = nil

        await withCheckedContinuation {
            factoryContinuation = $0
        }

        return WorkspaceRuntime(
            workspaceCatalog: provider
        )
    }

    func waitUntilCalled() async {
        guard callCount == 0 else {
            return
        }

        await withCheckedContinuation {
            callWaiter = $0
        }
    }

    func resume() {
        factoryContinuation?.resume()
        factoryContinuation = nil
    }
}

@MainActor
private final class MenuBarControllerSpy: MenuBarControlling {
    private(set) var isVisible: Bool = false
    private(set) var visibilityChanges: [Bool] = []
    private(set) var stopCallCount = 0

    func setVisible(_ isVisible: Bool) {
        self.isVisible = isVisible
        visibilityChanges.append(isVisible)
    }

    func stop() {
        stopCallCount += 1
        isVisible = false
    }
}

private enum StartupError: Error, Equatable {
    case expected
}

@MainActor
private func makeAgentRuntimeComponents(
    provider: WorkspaceProviderStub
) -> AgentRuntimeComponents {
    AgentRuntimeComponents(
        workspace: WorkspaceRuntime(
            workspaceCatalog: provider
        )
    )
}
