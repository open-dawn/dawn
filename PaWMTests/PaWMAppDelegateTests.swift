//
//  PaWMAppDelegateTests.swift
//  pineapplewm
//
//  Created by Rafael Venetikides on 21/09/26.
//

import AppKit
import PaEventKit
import Testing

@testable import PaWM

@MainActor
@Suite("PaWMAppDelegate")
struct PaWMAppDelegateTests {
    @Test("Start registers and retains listeners before starting service")
    func startRegistersListenersBeforeService() async throws {
        let service = EventBusServiceSpy()
        let provider = ContextProviderStub()

        let delegate = PaWMAppDelegate(
            eventBusService: service
        ) { bus in
            WindowManagerListener(
                bus: bus,
                contextManager: provider
            )
        }

        try await delegate.start()

        #expect(service.startCallCount == 1)
        #expect(service.listenersWereRegisteredWhenStarted)

        #expect(service.bus.hasListeners(for: .getContexts(PaGetContextsEvent())))
        #expect(service.bus.hasListeners(for: .debugPing(PaDebugPingEvent())))
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

        let delegate = PaWMAppDelegate(
            eventBusService: service
        ) { bus in
            WindowManagerListener(
                bus: bus,
                contextManager: provider
            )
        }

        try await delegate.start()

        let response = try await service.bus.ask(
            .getContexts(PaGetContextsEvent()),
            timeout: .seconds(1)
        )

        guard case .contextsFetched(let paContextsFetchedEvent) = response else {
            Issue.record("Expected contextsFetched, received \(response)")
            return
        }

        #expect(paContextsFetchedEvent.contexts == expectedContext)
    }

    @Test("Startup failure does not start event bus service")
    func startupFailureDoesNotStartService() async {
        let service = EventBusServiceSpy()

        let delegate = PaWMAppDelegate(
            eventBusService: service
        ) { _ in
            throw StartupError.expected
        }

        await #expect(throws: StartupError.expected) {
            try await delegate.start()
        }

        #expect(service.startCallCount == 0)
        #expect(!service.bus.hasListeners(for: .debugPing(PaDebugPingEvent())))
    }

    @Test("Termination stops service and releases listeners")
    func terminationStopsServiceAndReleasesListeners() async throws {
        let service = EventBusServiceSpy()
        let provider = ContextProviderStub()

        let delegate = PaWMAppDelegate(
            eventBusService: service
        ) { bus in
            WindowManagerListener(
                bus: bus,
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
        #expect(!service.bus.hasListeners(for: .getContexts(PaGetContextsEvent())))
        #expect(!service.bus.hasListeners(for: .debugPing(PaDebugPingEvent())))
    }
}

@MainActor
private final class EventBusServiceSpy: PaWMEventBusServicing {
    let bus = PaEventBus()

    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var listenersWereRegisteredWhenStarted = false

    func start() {
        startCallCount += 1

        let hasWorkspaceListener = bus.hasListeners(for: .getContexts(PaGetContextsEvent()))

        let hasDebugListener = bus.hasListeners(for: .debugPing(PaDebugPingEvent()))

        listenersWereRegisteredWhenStarted = hasWorkspaceListener && hasDebugListener
    }

    func stop() {
        stopCallCount += 1
    }
}

@MainActor
private final class ContextProviderStub: ContextProviding {
    private let contexts: [WorkspaceContext]

    init(contexts: [WorkspaceContext] = []) {
        self.contexts = contexts
    }

    func getAvailableContexts() async -> [WorkspaceContext] {
        contexts
    }
}

private enum StartupError: Error, Equatable {
    case expected
}
