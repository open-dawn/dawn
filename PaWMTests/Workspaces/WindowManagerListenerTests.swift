import PaEventKit
@testable import PaWM
import Testing

@MainActor
@Suite("WindowManagerListener")
struct WindowManagerListenerTests {
    @Test("bus uses WindowManagerListener as EventHandler")
    func busUseListernerAsHandler() throws {
        let events: [(event: PaEvent, afterResult: Bool)] = [
            (event: PaEvent.debugPing(PaDebugPingEvent()), afterResult: false),
            (event: PaEvent.initialized(PaInitializedEvent()), afterResult: true),
            (event: PaEvent.getContexts(PaGetContextsEvent()), afterResult: true),
            (event: PaEvent.switchSpace(PaSwitchSpaceEvent(spaceIndex: 1)), afterResult: true)
        ]

        let mockBus = PaEventBus()
        for event in events {
            try #require(mockBus.hasListeners(for: event.event) == false)
        }

        let listener = WindowManagerListener(bus: mockBus)
        for event in events {
            #expect(mockBus.hasListeners(for: event.event) == event.afterResult)
        }
    }

    @Test("handle get contexts event")
    func handle_GetContextsEvent() async throws {
        let mockBus = PaEventBus()
        let mockContextManager = FakeContextManager()
        let listener = WindowManagerListener(bus: mockBus, contextManager: mockContextManager)

        let event = PaEvent.getContexts(PaGetContextsEvent())
        let eventResponse = try await mockBus.ask(event)

        guard case let .contextsFetched(payload) = eventResponse else {
            Issue.record("Expected .contextsFetched \(eventResponse)")
            return
        }
        #expect(payload.contexts == mockContextManager.contexts)
    }

    @Test("switchSpace with valid index switches that context")
    func handle_switchSpaceValidIndex() {
        let mockContextManager = FakeContextManager()
        mockContextManager.contexts = [WorkspaceContext](repeating: createMockWorkspaceContext(), count: 3)
        let switcherSpy = ContextSwitchingSpy()
        let mockBus = PaEventBus()
        let listener = WindowManagerListener(bus: mockBus,
                                             contextManager: mockContextManager,
                                             contextSwitching: switcherSpy)
        let event = PaEvent.switchSpace(PaSwitchSpaceEvent(spaceIndex: 1))

        listener.handle(event, reply: nil)
        #expect(switcherSpy.switchedContexts == [mockContextManager.contexts[1]])
    }

    @Test("switchSpace with invalid index switches that context")
    func handle_switchSpaceInvalidIndex() {
        let mockContextManager = FakeContextManager()
        mockContextManager.contexts = [WorkspaceContext](repeating: createMockWorkspaceContext(), count: 1)
        let switcherSpy = ContextSwitchingSpy()
        let mockBus = PaEventBus()
        let listener = WindowManagerListener(bus: mockBus,
                                             contextManager: mockContextManager,
                                             contextSwitching: switcherSpy)
        let event = PaEvent.switchSpace(PaSwitchSpaceEvent(spaceIndex: 2))

        listener.handle(event, reply: nil)
        #expect(switcherSpy.switchedContexts == [])
    }

    @Test("getAllContexts return the same of ContextManager")
    func getAllContextsRespectContextManagerReturns() {
        let mockContextManager = FakeContextManager()
        mockContextManager.contexts = [WorkspaceContext](repeating: createMockWorkspaceContext(), count: 3)

        let mockBus = PaEventBus()
        let listener = WindowManagerListener(bus: mockBus, contextManager: mockContextManager)

        #expect(listener.getAllContexts() == mockContextManager.contexts)
    }

    @Test("getAllContexts returns the same data as ContextManager")
    func getAllContexts_returnsContextManagerValues() {
        let mockContextManager = FakeContextManager()
        mockContextManager.contexts = [WorkspaceContext](repeating: createMockWorkspaceContext(), count: 3)

        let mockBus = PaEventBus()
        let listener = WindowManagerListener(bus: mockBus, contextManager: mockContextManager)

        #expect(listener.getContextWithIndex(0) == mockContextManager.contexts[0])
    }

    @Test("getContext with valid index returns the correct context")
    func getContextWithIndex_correctContext() {
        let mockContextManager = FakeContextManager()
        mockContextManager.contexts = [WorkspaceContext](repeating: createMockWorkspaceContext(), count: 3)

        let mockBus = PaEventBus()
        let listener = WindowManagerListener(bus: mockBus, contextManager: mockContextManager)

        #expect(listener.getContextWithIndex(1) == mockContextManager.contexts[1])
    }

    @Test("getContext with invalid index returns nil when context does not exist")
    func getContextWithIndex_nilContext() {
        let mockContextManager = FakeContextManager()
        mockContextManager.contexts = []

        let mockBus = PaEventBus()
        let listener = WindowManagerListener(bus: mockBus, contextManager: mockContextManager)

        #expect(listener.getContextWithIndex(1) == nil)
    }

    private func createMockWorkspaceContext() -> WorkspaceContext {
        WorkspaceContext(name: "placeholder", symbol: "", applications: [])
    }
}

final class FakeContextManager: ContextProviding {
    var contexts: [WorkspaceContext] = []

    func getAvailableContexts() -> [WorkspaceContext] {
        return contexts
    }
}

final class ContextSwitchingSpy: ContextSwitching {
    var switchedContexts: [WorkspaceContext] = []

    func switchToContext(to context: WorkspaceContext) {
        switchedContexts.append(context)
    }
}
