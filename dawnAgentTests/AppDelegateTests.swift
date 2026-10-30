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
        let provider = ContextProviderStub()
        let menuBarController = MenuBarControllerSpy()

        let delegate = AppDelegate(
            eventBusService: service,
            makeMenuBarController: { _, _ in
                menuBarController
            },
            makeAgentRuntime: { _ in
                makeAgentRuntimeComponents(
                    provider: provider
                )
            }
        )

        try await delegate.start()

        #expect(service.startCallCount == 1)
        #expect(service.listenersWereRegisteredWhenStarted)

        #expect(service.bus.hasListeners(for: .getContexts(GetContextsEvent())))
        #expect(service.bus.hasListeners(for: .debugPing(DebugPingEvent())))
    }

    @Test("Retained workspace listener answers context requests")
    func retainedListenerAnswersContextRequests() async throws {
        let expectedContext = [
            WorkspaceContext(
                name: "Study",
                symbol: "book"
            )
        ]

        let service = EventBusServiceSpy()
        let provider = ContextProviderStub(contexts: expectedContext)
        let menuBarController = MenuBarControllerSpy()

        let delegate = AppDelegate(
            eventBusService: service,
            makeMenuBarController: { _, _ in
                menuBarController
            },
            makeAgentRuntime: { _ in
                makeAgentRuntimeComponents(
                    provider: provider
                )
            }
        )

        try await delegate.start()

        let response = try await service.bus.ask(
            .getContexts(GetContextsEvent()),
            timeout: .seconds(1)
        )

        guard case .contextsFetched(let contextsFetchedEvent) = response else {
            Issue.record("Expected contextsFetched, received \(response)")
            return
        }

        #expect(contextsFetchedEvent.contexts == expectedContext)
    }

    @Test("Startup failure does not start event bus service")
    func startupFailureDoesNotStartService() async {
        let service = EventBusServiceSpy()
        let menuBarController = MenuBarControllerSpy()

        let delegate = AppDelegate(
            eventBusService: service,
            makeMenuBarController: { _, _ in
                menuBarController
            },
            makeAgentRuntime: { _ in
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
        let provider = ContextProviderStub()
        let menuBarController = MenuBarControllerSpy()

        let delegate = AppDelegate(
            eventBusService: service,
            makeMenuBarController: { _, _ in
                menuBarController
            },
            makeAgentRuntime: { _ in
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
        #expect(!service.bus.hasListeners(for: .getContexts(GetContextsEvent())))
        #expect(!service.bus.hasListeners(for: .debugPing(DebugPingEvent())))
        #expect(menuBarController.stopCallCount == 1)
        #expect(!service.bus.hasListeners(for: .getMenuBarVisibility(GetMenuBarVisibilityEvent())))

        #expect(!service.bus.hasListeners(for: .setMenuBarVisibility(SetMenuBarVisibilityEvent(isVisible: false))))
    }

    @Test("Repeated starts initialize only once")
    func repeatedStartsInitializeOnlyOnce() async throws {
        let service = EventBusServiceSpy()
        let provider = ContextProviderStub()
        var factoryCallCount = 0
        let menuBarController = MenuBarControllerSpy()

        let delegate = AppDelegate(
            eventBusService: service,
            makeMenuBarController: { _, _ in
                menuBarController
            },
            makeAgentRuntime: { _ in
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
        let provider = ContextProviderStub()
        let factory = PausingWorkspaceRuntimeFactory(provider: provider)
        let menuBarController = MenuBarControllerSpy()
        let visibilityStore = MenuBarVisibilityStoreStub()

        let delegate = AppDelegate(
            eventBusService: service,
            makeMenuBarController: { _, _ in
                menuBarController
            },
            makeAgentRuntime: { _ in
                AgentRuntimeComponents(
                    workspace: await factory.makeRuntime(),
                    menuBarVisibilityStore: visibilityStore
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
        let provider = ContextProviderStub()
        var attemptCount = 0
        let menuBarController = MenuBarControllerSpy()

        let delegate = AppDelegate(
            eventBusService: service,
            makeMenuBarController: { _, _ in
                menuBarController
            },
            makeAgentRuntime: { _ in
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

        let expectedContexts = [
            WorkspaceContext(
                name: "Study",
                symbol: "book"
            )
        ]

        let provider = ContextProviderStub(
            contexts: expectedContexts
        )

        let runtime = WorkspaceRuntime(
            contextManager: provider
        )

        let menuBarController = MenuBarControllerSpy()

        let delegate = AppDelegate(
            eventBusService: service,
            makeMenuBarController: { _, _ in
                menuBarController
            },
            makeAgentRuntime: { _ in
                AgentRuntimeComponents(
                    workspace: runtime,
                    menuBarVisibilityStore:
                        MenuBarVisibilityStoreStub()
                )
            }
        )

        try await delegate.start()

        #expect(provider.getWorkspaceSnapshotCallCount == 1)
        #expect(runtime.contexts == expectedContexts)
        #expect(provider.stopActiveContextCallCount == 0)
    }

    @Test("Start creates menu controller with shared runtime once")
    func startCreatesMenuControllerOnce() async throws {
        let service = EventBusService()
        let provider = ContextProviderStub()

        let runtime = WorkspaceRuntime(
            contextManager: provider
        )

        let menuBarController = MenuBarControllerSpy()

        var factoryCallCount = 0
        var receivedWorkspace: WorkspaceRuntime?

        let delegate = AppDelegate(
            eventBusService: service,
            makeMenuBarController: { workspace, _ in
                factoryCallCount += 1
                receivedWorkspace = workspace
                return menuBarController
            },
            makeAgentRuntime: { _ in
                AgentRuntimeComponents(
                    workspace: runtime,
                    menuBarVisibilityStore:
                        MenuBarVisibilityStoreStub()
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
        let context = WorkspaceContext(
            name: "Work",
            symbol: "briefcase"
        )

        let provider = ContextProviderStub(
            contexts: [context]
        )

        provider.workspaceActivity.activate(
            contextID: context.id,
            at: Date(timeIntervalSince1970: 100)
        )

        let runtime = WorkspaceRuntime(
            contextManager: provider
        )

        let service = EventBusServiceSpy()
        let menuBarController = MenuBarControllerSpy()

        var activeContextReceivedByMenuBar: UUID?

        let delegate = AppDelegate(
            eventBusService: service,
            makeMenuBarController: { workspace, _ in
                activeContextReceivedByMenuBar =
                    workspace.activeContextID

                return menuBarController
            },
            makeAgentRuntime: { _ in
                AgentRuntimeComponents(
                    workspace: runtime,
                    menuBarVisibilityStore:
                        MenuBarVisibilityStoreStub()
                )
            }
        )

        try await delegate.start()

        #expect(provider.stopActiveContextCallCount == 1)
        #expect(provider.workspaceActivity.activeContextID == nil)
        #expect(runtime.activeContextID == nil)
        #expect(activeContextReceivedByMenuBar == nil)

        #expect(
            runtime.lastActiveAt(for: context.id)
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
        let provider = ContextProviderStub()
        let visibilityStore =
            MenuBarVisibilityStoreStub(
                isVisible: expectedVisibility
            )

        let menuBarController =
            MenuBarControllerSpy()

        var receivedVisibility: Bool?

        let delegate = AppDelegate(
            eventBusService: service,
            makeMenuBarController: { _, isVisible in
                receivedVisibility = isVisible
                return menuBarController
            },
            makeAgentRuntime: { _ in
                makeAgentRuntimeComponents(
                    provider: provider,
                    visibilityStore: visibilityStore
                )
            }
        )

        try await delegate.start()

        #expect(
            receivedVisibility == expectedVisibility
        )
    }

    @Test("Retained visibility listener answers requests")
    func retainedVisibilityListenerAnswersRequests()
        async throws
    {
        let service = EventBusServiceSpy()
        let provider = ContextProviderStub()
        let visibilityStore =
            MenuBarVisibilityStoreStub(
                isVisible: false
            )

        let menuBarController =
            MenuBarControllerSpy()

        let delegate = AppDelegate(
            eventBusService: service,
            makeMenuBarController: { _, _ in
                menuBarController
            },
            makeAgentRuntime: { _ in
                makeAgentRuntimeComponents(
                    provider: provider,
                    visibilityStore: visibilityStore
                )
            }
        )

        try await delegate.start()

        let response = try await service.bus.ask(
            .getMenuBarVisibility(
                GetMenuBarVisibilityEvent()
            ),
            timeout: .seconds(1)
        )

        #expect(
            response
                == .menuBarVisibilityState(
                    MenuBarVisibilityStateEvent(
                        isVisible: false
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
            for: .getContexts(
                GetContextsEvent()
            )
        )

        let hasDebugListener = bus.hasListeners(
            for: .debugPing(
                DebugPingEvent()
            )
        )

        let hasVisibilityGetter = bus.hasListeners(
            for: .getMenuBarVisibility(
                GetMenuBarVisibilityEvent()
            )
        )

        let hasVisibilitySetter = bus.hasListeners(
            for: .setMenuBarVisibility(
                SetMenuBarVisibilityEvent(
                    isVisible: false
                )
            )
        )

        listenersWereRegisteredWhenStarted =
            hasWorkspaceListener
            && hasDebugListener
            && hasVisibilityGetter
            && hasVisibilitySetter
    }

    func stop() {
        stopCallCount += 1
    }
}

@MainActor
private final class ContextProviderStub: WorkspaceManaging {
    private(set) var getWorkspaceSnapshotCallCount = 0
    private(set) var stopActiveContextCallCount = 0
    private(set) var lastStopDate: Date?

    private let contexts: [WorkspaceContext]

    var workspaceActivity: WorkspaceActivityState = .empty

    func createContext(
        name: String,
        symbol: String,
        applications: [WorkspaceApplication]
    ) async throws -> WorkspaceContext {
        WorkspaceContext(name: name, symbol: symbol, applications: applications)
    }

    func updateContext(_ context: WorkspaceContext) async throws {
    }

    func deleteContext(id: UUID) async throws {
    }

    func getContext(id: UUID) async -> WorkspaceContext? {
        WorkspaceContext(id: id, name: "Placeholder", symbol: "book")
    }

    init(contexts: [WorkspaceContext] = []) {
        self.contexts = contexts
    }

    func getAvailableContexts() async -> [WorkspaceContext] {
        return contexts
    }

    func getWorkspaceActivity() async -> WorkspaceActivityState {
        workspaceActivity
    }

    func recordContextActivation(contextID: UUID, at date: Date) async throws -> WorkspaceActivityState {
        guard contexts.contains(where: { $0.id == contextID }) else {
            throw SettingsStoreError.contextNotFound(contextID)
        }

        workspaceActivity.activate(
            contextID: contextID,
            at: date
        )

        return workspaceActivity
    }

    func stopActiveContext(at date: Date) async throws -> WorkspaceActivityState {
        stopActiveContextCallCount += 1
        lastStopDate = date

        workspaceActivity.stop(at: date)

        return workspaceActivity
    }

    func getWorkspaceSnapshot() async -> WorkspaceSnapshot {
        getWorkspaceSnapshotCallCount += 1

        return WorkspaceSnapshot(
            contexts: contexts,
            activity: workspaceActivity
        )
    }
}

@MainActor
private final class PausingWorkspaceRuntimeFactory {
    private let provider: ContextProviderStub
    private var callWaiter: CheckedContinuation<Void, Never>?
    private var factoryContinuation: CheckedContinuation<Void, Never>?

    private(set) var callCount = 0

    init(provider: ContextProviderStub) {
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
            contextManager: provider
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

private actor MenuBarVisibilityStoreStub:
    MenuBarVisibilityStoring
{
    private var isVisible: Bool

    init(isVisible: Bool = true) {
        self.isVisible = isVisible
    }

    func menuBarIsVisible() async -> Bool {
        isVisible
    }

    func setMenuBarVisible(
        _ isVisible: Bool
    ) async throws {
        self.isVisible = isVisible
    }
}

@MainActor
private func makeAgentRuntimeComponents(
    provider: ContextProviderStub,
    visibilityStore:
        any MenuBarVisibilityStoring =
        MenuBarVisibilityStoreStub()
) -> AgentRuntimeComponents {
    AgentRuntimeComponents(
        workspace: WorkspaceRuntime(
            contextManager: provider
        ),
        menuBarVisibilityStore: visibilityStore
    )
}
