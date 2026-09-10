import PaEventKit
@testable import PaWM
import Testing

@MainActor
@Suite("WindowManagerListener")
struct WindowManagerListenerTests {
    @Test("handle invalid event does nothing")
    func handle_invalidEventdoesNothing() {
        let mockBus = PaEventBus()
        let listener = WindowManagerListener(bus: mockBus)

        let event = PaEvent.debugPing(PaDebugPingEvent())
        mockBus.publish(event)
    }

    @Test("handle initialize event")
    func handle_InitializeEvent() {
        let mockBus = PaEventBus()
        let listener = WindowManagerListener(bus: mockBus)

        let event = PaEvent.initialized(PaInitializedEvent())
        mockBus.publish(event)
    }

    @Test("handle get contexts event")
    func handle_GetContextsEvent() async throws {
        let mockBus = PaEventBus()
        let mockContextManager = FakeContextManager()
        let listener = WindowManagerListener(bus: mockBus, contextManager: mockContextManager)

        let event = PaEvent.getContexts(PaGetContextsEvent())
        let eventResponse = try #require(await mockBus.ask(event))
        guard case let .contextsFetched(payload) = eventResponse else {
            Issue.record("Expected .contextsFetched \(eventResponse)")
            return
        }
        #expect(payload.contexts == mockContextManager.contexts)
    }

    @Test("handle switch space event with valid id")
    func handle_SwitchSpaceEventwithValidId() {
        let mockBus = PaEventBus()
        let mockContextManager = FakeContextManager()
        mockContextManager.contexts = [WorkspaceContext](repeating: createMockWorkspaceContext(), count: 3)
        let listener = WindowManagerListener(bus: mockBus, contextManager: mockContextManager)

        let event = PaEvent.switchSpace(PaSwitchSpaceEvent(spaceIndex: 1))
        mockBus.publish(event)
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
