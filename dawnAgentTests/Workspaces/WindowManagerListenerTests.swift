import Foundation
import libdawn
import Testing

@testable import dawnAgent

@MainActor
@Suite("WindowManagerListener")
struct WindowManagerListenerTests {
    @Test("bus uses WindowManagerListener as EventHandler")
    func busUseListernerAsHandler() throws {
        let events: [(event: PaEvent, afterResult: Bool)] = [
            (event: PaEvent.debugPing(PaDebugPingEvent()), afterResult: false),
            (event: PaEvent.initialized(PaInitializedEvent()), afterResult: true),
            (event: PaEvent.getContexts(PaGetContextsEvent()), afterResult: true),
            (event: PaEvent.switchSpace(PaSwitchSpaceEvent(spaceIndex: 1)), afterResult: true),
            (
                event: PaEvent.createContext(
                    PaCreateContextEvent(name: "Placeholder", symbol: "book", applications: [])
                ), afterResult: true
            ),
            (
                event: PaEvent.updateContext(
                    PaUpdateContextEvent(context: WorkspaceContext(name: "Placeholder", symbol: "book"))
                ), afterResult: true
            ),
            (event: PaEvent.deleteContext(PaDeleteContextEvent(contextID: UUID())), afterResult: true),
            (event: PaEvent.switchContext(PaSwitchContextEvent(contextID: UUID())), afterResult: true),
        ]

        let mockBus = PaEventBus()

        for event in events {
            try #require(mockBus.hasListeners(for: event.event) == false)
        }

        let mockContextManager = FakeContextManager()
        let listener = WindowManagerListener(bus: mockBus, contextManager: mockContextManager)
        for event in events {
            #expect(mockBus.hasListeners(for: event.event) == event.afterResult)
        }

        _ = listener  // Fix warning of not used variable
    }

    @Test("handle get contexts event")
    func handle_GetContextsEvent() async throws {
        let mockBus = PaEventBus()
        let mockContextManager = FakeContextManager()
        let listener = WindowManagerListener(bus: mockBus, contextManager: mockContextManager)

        let event = PaEvent.getContexts(PaGetContextsEvent())
        let eventResponse = try await mockBus.ask(event)

        guard case .contextsFetched(let payload) = eventResponse else {
            Issue.record("Expected .contextsFetched \(eventResponse)")
            return
        }
        #expect(payload.contexts == mockContextManager.contexts)

        _ = listener  // Fix warning of not used variable
    }

    @Test("switchSpace with valid index switches that context")
    func handle_switchSpaceValidIndex() async {
        let mockContextManager = FakeContextManager()
        mockContextManager.contexts = createMockWorkspaceContext(3)
        let switcherSpy = ContextSwitchingSpy()
        let mockBus = PaEventBus()
        let listener = WindowManagerListener(
            bus: mockBus,
            contextManager: mockContextManager,
            contextSwitching: switcherSpy
        )
        let event = PaEvent.switchSpace(PaSwitchSpaceEvent(spaceIndex: 1))

        listener.handle(event, reply: nil)
        await mockContextManager.waitUntilSwitched()

        #expect(switcherSpy.switchedContexts == [mockContextManager.contexts[1]])
    }

    @Test("switchSpace with invalid index switches that context")
    func handle_switchSpaceInvalidIndex() async {
        let mockContextManager = FakeContextManager()
        mockContextManager.contexts = createMockWorkspaceContext(1)
        let switcherSpy = ContextSwitchingSpy()
        let mockBus = PaEventBus()
        let listener = WindowManagerListener(
            bus: mockBus,
            contextManager: mockContextManager,
            contextSwitching: switcherSpy
        )
        let event = PaEvent.switchSpace(PaSwitchSpaceEvent(spaceIndex: 2))

        listener.handle(event, reply: nil)
        await mockContextManager.waitUntilSwitched()

        #expect(switcherSpy.switchedContexts == [])
    }

    @Test("getAllContexts return the same of ContextManager")
    func getAllContextsRespectContextManagerReturns() async {
        let mockContextManager = FakeContextManager()
        mockContextManager.contexts = createMockWorkspaceContext(3)

        let mockBus = PaEventBus()
        let listener = WindowManagerListener(bus: mockBus, contextManager: mockContextManager)

        #expect(await listener.getAllContexts() == mockContextManager.contexts)
    }

    @Test("getAllContexts returns the same data as ContextManager")
    func getAllContexts_returnsContextManagerValues() async {
        let mockContextManager = FakeContextManager()
        mockContextManager.contexts = createMockWorkspaceContext(3)

        let mockBus = PaEventBus()
        let listener = WindowManagerListener(bus: mockBus, contextManager: mockContextManager)

        #expect(await listener.getContextWithIndex(0) == mockContextManager.contexts[0])
    }

    @Test("getContext with valid index returns the correct context")
    func getContextWithIndex_correctContext() async {
        let mockContextManager = FakeContextManager()
        mockContextManager.contexts = createMockWorkspaceContext(3)

        let mockBus = PaEventBus()
        let listener = WindowManagerListener(bus: mockBus, contextManager: mockContextManager)

        #expect(await listener.getContextWithIndex(1) == mockContextManager.contexts[1])
    }

    @Test("getContext with invalid index returns nil when context does not exist")
    func getContextWithIndex_nilContext() async {
        let mockContextManager = FakeContextManager()
        mockContextManager.contexts = []

        let mockBus = PaEventBus()
        let listener = WindowManagerListener(bus: mockBus, contextManager: mockContextManager)

        #expect(await listener.getContextWithIndex(1) == nil)
    }

    @Test("Create routes payload and replies with created context ID")
    func createRoutesPayloadAndRepliesWithSuccess() async throws {
        let application = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari"
        )

        let payload = PaCreateContextEvent(
            name: "Work",
            symbol: "briefcase",
            applications: [application]
        )

        let createdContext = WorkspaceContext(
            name: payload.name,
            symbol: payload.symbol,
            applications: payload.applications
        )

        let contextManager = FakeContextManager()
        contextManager.createResult = createdContext

        let bus = PaEventBus()
        let listener = WindowManagerListener(
            bus: bus,
            contextManager: contextManager
        )

        let response = try await bus.ask(.createContext(payload))

        #expect(contextManager.createPayloads == [payload])
        #expect(
            response
                == .contextMutationAcknowledged(
                    .success(contextID: createdContext.id)
                )
        )

        _ = listener
    }

    @Test("Create replies with validation failure")
    func createRepliesWithValidationFailure() async throws {
        let payload = PaCreateContextEvent(
            name: "",
            symbol: "briefcase",
            applications: []
        )

        let contextManager = FakeContextManager()
        contextManager.createError = SettingsStoreError.emptyContextName

        let bus = PaEventBus()
        let listener = WindowManagerListener(
            bus: bus,
            contextManager: contextManager
        )

        let response = try await bus.ask(.createContext(payload))

        #expect(contextManager.createPayloads == [payload])
        #expect(
            response
                == .contextMutationAcknowledged(
                    .failure(failure: .emptyContextName)
                )
        )
        #expect(contextManager.contexts.isEmpty)

        _ = listener
    }

    @Test("Published create command does not mutate contexts")
    func publishedCreateDoesNotMutateContexts() {
        let payload = PaCreateContextEvent(
            name: "Work",
            symbol: "briefcase",
            applications: []
        )

        let contextManager = FakeContextManager()
        let bus = PaEventBus()
        let listener = WindowManagerListener(
            bus: bus,
            contextManager: contextManager
        )

        listener.handle(.createContext(payload), reply: nil)

        #expect(contextManager.createPayloads.isEmpty)
        #expect(contextManager.contexts.isEmpty)
    }

    @Test("Update routes context and replies with its ID")
    func updateRoutesContextAndRepliesWithSuccess() async throws {
        var context = WorkspaceContext(
            name: "Work",
            symbol: "briefcase",
            applications: []
        )

        let contextManager = FakeContextManager()
        contextManager.contexts = [context]

        context.name = "Updated Work"

        let payload = PaUpdateContextEvent(context: context)
        let bus = PaEventBus()
        let listener = WindowManagerListener(
            bus: bus,
            contextManager: contextManager
        )

        let response = try await bus.ask(.updateContext(payload))

        #expect(contextManager.updatedContexts == [context])
        #expect(contextManager.contexts == [context])
        #expect(
            response
                == .contextMutationAcknowledged(
                    .success(contextID: context.id)
                )
        )

        _ = listener
    }

    @Test("Update replies with context-not-found failure")
    func updateRepliesWithMissingContextFailure() async throws {
        let context = WorkspaceContext(
            name: "Missing",
            symbol: "questionmark",
            applications: []
        )

        let contextManager = FakeContextManager()
        contextManager.updateError = SettingsStoreError.contextNotFound(
            context.id
        )

        let bus = PaEventBus()
        let listener = WindowManagerListener(
            bus: bus,
            contextManager: contextManager
        )

        let response = try await bus.ask(
            .updateContext(
                PaUpdateContextEvent(context: context)
            )
        )

        #expect(contextManager.updatedContexts == [context])
        #expect(
            response
                == .contextMutationAcknowledged(
                    .failure(
                        failure: .contextNotFound(context.id)
                    )
                )
        )

        _ = listener
    }

    @Test("Delete replies with context-not-found failure")
    func deleteRepliesWithMissingContextFailure() async throws {
        let missingID = UUID()

        let contextManager = FakeContextManager()
        contextManager.deleteError = SettingsStoreError.contextNotFound(
            missingID
        )

        let bus = PaEventBus()
        let listener = WindowManagerListener(
            bus: bus,
            contextManager: contextManager
        )

        let response = try await bus.ask(
            .deleteContext(
                PaDeleteContextEvent(contextID: missingID)
            )
        )

        #expect(contextManager.deletedContextIDs == [missingID])
        #expect(
            response
                == .contextMutationAcknowledged(
                    .failure(
                        failure: .contextNotFound(missingID)
                    )
                )
        )

        _ = listener
    }

    @Test("Delete routes ID and replies with deleted context ID")
    func deleteRoutesIDAndRepliesWithSuccess() async throws {
        let context = WorkspaceContext(
            name: "Work",
            symbol: "briefcase",
            applications: []
        )

        let contextManager = FakeContextManager()
        contextManager.contexts = [context]

        let payload = PaDeleteContextEvent(contextID: context.id)
        let bus = PaEventBus()
        let listener = WindowManagerListener(
            bus: bus,
            contextManager: contextManager
        )

        let response = try await bus.ask(.deleteContext(payload))

        #expect(contextManager.deletedContextIDs == [context.id])
        #expect(contextManager.contexts.isEmpty)
        #expect(
            response
                == .contextMutationAcknowledged(
                    .success(contextID: context.id)
                )
        )

        _ = listener
    }

    @Test("Switch context activates context and replies with its ID")
    func switchContextActivatesContextAndRepliesWithSuccess() async throws {
        let context = WorkspaceContext(
            name: "Work",
            symbol: "briefcase",
            applications: []
        )

        let contextManager = FakeContextManager()
        contextManager.contexts = [context]

        let switcher = ContextSwitchingSpy()
        let bus = PaEventBus()
        let listener = WindowManagerListener(
            bus: bus,
            contextManager: contextManager,
            contextSwitching: switcher
        )

        let response = try await bus.ask(
            .switchContext(
                PaSwitchContextEvent(contextID: context.id)
            )
        )

        #expect(switcher.switchedContexts == [context])
        #expect(
            response
                == .contextMutationAcknowledged(
                    .success(contextID: context.id)
                )
        )

        _ = listener
    }

    @Test("Switch context replies with context-not-found")
    func switchContextRepliesWithMissingContextFailure() async throws {
        let missingID = UUID()

        let contextManager = FakeContextManager()
        let switcher = ContextSwitchingSpy()
        let bus = PaEventBus()
        let listener = WindowManagerListener(
            bus: bus,
            contextManager: contextManager,
            contextSwitching: switcher
        )

        let response = try await bus.ask(
            .switchContext(
                PaSwitchContextEvent(contextID: missingID)
            )
        )

        #expect(switcher.switchedContexts.isEmpty)
        #expect(
            response
                == .contextMutationAcknowledged(
                    .failure(
                        failure: .contextNotFound(missingID)
                    )
                )
        )

        _ = listener
    }

    private func createMockWorkspaceContext(_ count: Int) -> [WorkspaceContext] {
        var res: [WorkspaceContext] = []
        for index in 1...count {
            res.append(WorkspaceContext(name: "placeholder \(index)", symbol: "", applications: []))
        }
        return res
    }
}

@MainActor
final class FakeContextManager: ContextProviding {
    var contexts: [WorkspaceContext] = []

    private var continuation: CheckedContinuation<Void, Never>?

    private(set) var createPayloads: [PaCreateContextEvent] = []
    var createResult: WorkspaceContext?
    var createError: Error?

    private(set) var updatedContexts: [WorkspaceContext] = []
    var updateError: Error?

    private(set) var deletedContextIDs: [UUID] = []
    var deleteError: Error?

    func getAvailableContexts() -> [WorkspaceContext] {
        defer {
            continuation?.resume()
            continuation = nil
        }
        return contexts
    }

    func createContext(name: String, symbol: String, applications: [WorkspaceApplication]) async throws
        -> WorkspaceContext
    {
        createPayloads.append(
            PaCreateContextEvent(
                name: name,
                symbol: symbol,
                applications: applications
            )
        )

        if let createError {
            throw createError
        }

        let context =
            createResult
            ?? WorkspaceContext(
                name: name,
                symbol: symbol,
                applications: applications
            )

        contexts.append(context)
        return context
    }

    func updateContext(_ context: WorkspaceContext) async throws {
        updatedContexts.append(context)

        if let updateError {
            throw updateError
        }

        guard let index = contexts.firstIndex(where: { $0.id == context.id }) else {
            return
        }

        contexts[index] = context
    }

    func deleteContext(id: UUID) async throws {
        deletedContextIDs.append(id)

        if let deleteError {
            throw deleteError
        }

        contexts.removeAll { $0.id == id }
    }

    func getContext(id: UUID) async -> WorkspaceContext? {
        contexts.first { $0.id == id }
    }

    func waitUntilSwitched() async {
        await withCheckedContinuation { continuation = $0 }
    }
}

final class ContextSwitchingSpy: ContextSwitching {
    var switchedContexts: [WorkspaceContext] = []

    func switchToContext(to context: WorkspaceContext) {
        switchedContexts.append(context)
    }
}
