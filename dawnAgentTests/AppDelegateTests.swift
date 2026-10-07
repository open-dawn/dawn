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

        let delegate = AppDelegate(
            eventBusService: service
        ) { _ in
            WorkspaceRuntime(
                contextManager: provider
            )
        }

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

        let delegate = AppDelegate(
            eventBusService: service
        ) { _ in
            WorkspaceRuntime(
                contextManager: provider
            )
        }

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

        let delegate = AppDelegate(
            eventBusService: service
        ) { _ in
            throw StartupError.expected
        }

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

        let delegate = AppDelegate(
            eventBusService: service
        ) { _ in
            WorkspaceRuntime(
                contextManager: provider
            )
        }

        try await delegate.start()

        delegate.applicationWillTerminate(
            Notification(
                name: NSApplication.willTerminateNotification
            )
        )

        #expect(service.stopCallCount == 1)
        #expect(!service.bus.hasListeners(for: .getContexts(GetContextsEvent())))
        #expect(!service.bus.hasListeners(for: .debugPing(DebugPingEvent())))
    }

    @Test("Repeated starts initialize only once")
    func repeatedStartsInitializeOnlyOnce() async throws {
        let service = EventBusServiceSpy()
        let provider = ContextProviderStub()
        var factoryCallCount = 0

        let delegate = AppDelegate(eventBusService: service) { _ in
            factoryCallCount += 1

            return WorkspaceRuntime(
                contextManager: provider
            )
        }

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

        let delegate = AppDelegate(
            eventBusService: service
        ) { _ in
            await factory.makeRuntime()
        }

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

        let delegate = AppDelegate(
            eventBusService: service
        ) { _ in
            attemptCount += 1

            if attemptCount == 1 {
                throw StartupError.expected
            }

            return WorkspaceRuntime(
                contextManager: provider
            )
        }

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

        let delegate = AppDelegate(
            eventBusService: service
        ) { _ in
            runtime
        }

        try await delegate.start()

        #expect(provider.getAvailableContextsCallCount == 1)
        #expect(runtime.contexts == expectedContexts)
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

        let hasWorkspaceListener = bus.hasListeners(for: .getContexts(GetContextsEvent()))

        let hasDebugListener = bus.hasListeners(for: .debugPing(DebugPingEvent()))

        listenersWereRegisteredWhenStarted = hasWorkspaceListener && hasDebugListener
    }

    func stop() {
        stopCallCount += 1
    }
}

@MainActor
private final class ContextProviderStub: ContextProviding {
    private(set) var getAvailableContextsCallCount = 0

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

    private let contexts: [WorkspaceContext]

    init(contexts: [WorkspaceContext] = []) {
        self.contexts = contexts
    }

    func getAvailableContexts() async -> [WorkspaceContext] {
        getAvailableContextsCallCount += 1
        return contexts
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

private enum StartupError: Error, Equatable {
    case expected
}
