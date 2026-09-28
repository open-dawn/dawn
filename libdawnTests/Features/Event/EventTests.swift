import Foundation
import Testing

@testable import libdawn

@Suite("Event")
struct EventTests {
    @Test(
        "kind matches each event case",
        arguments: [
            (event: Event.debugPing(DebugPingEvent()), kind: EventKind.debugPing),
            (event: Event.debugPong(DebugPongEvent()), kind: EventKind.debugPong),
            (event: Event.switchSpace(SwitchSpaceEvent(spaceIndex: 2)), kind: EventKind.switchSpace),
            (event: Event.initialized(InitializedEvent()), kind: EventKind.initialized),
            (event: Event.getContexts(GetContextsEvent()), kind: EventKind.getContexts),
            (event: Event.contextsFetched(ContextsFetchedEvent(contexts: [])), kind: EventKind.contextsFetched),
            (
                event: Event.availableContexts(AvailableContextsEvent(contexts: [])),
                kind: EventKind.availableContexts
            ),
            (
                event: Event.createContext(
                    CreateContextEvent(name: "placeholder", symbol: "book", applications: [])
                ),
                kind: EventKind.createContext
            ),
            (
                event: Event.updateContext(
                    UpdateContextEvent(
                        context: WorkspaceContext(name: "placeholder", symbol: "book")
                    )
                ),
                kind: EventKind.updateContext
            ),
            (event: Event.deleteContext(DeleteContextEvent(contextID: UUID())), kind: EventKind.deleteContext),
            (
                event: Event.switchContext(SwitchContextEvent(contextID: UUID())),
                kind: EventKind.switchContext
            ),
            (
                event: Event.contextMutationAcknowledged(.success(contextID: UUID())),
                kind: EventKind.contextMutationAcknowledged
            ),
        ]
    )
    func exposesKind(_ eventWithKind: (event: Event, kind: EventKind)) {
        #expect(eventWithKind.event.kind == eventWithKind.kind)
    }

    @Test(
        "Codable round-trips all cases",
        arguments: [
            Event.debugPing(DebugPingEvent()),
            .debugPong(DebugPongEvent(message: "hello")),
            .switchSpace(SwitchSpaceEvent(spaceIndex: 3)),
            .initialized(InitializedEvent()),
            .getContexts(GetContextsEvent()),
            .contextsFetched(ContextsFetchedEvent(contexts: [])),
            .createContext(CreateContextEvent(name: "placeholder", symbol: "book", applications: [])),
            .updateContext(UpdateContextEvent(context: WorkspaceContext(name: "placeholder", symbol: "book"))),
            .deleteContext(DeleteContextEvent(contextID: UUID())),
            .switchContext(SwitchContextEvent(contextID: UUID())),
            .contextMutationAcknowledged(ContextMutationAcknowledgement.success(contextID: UUID())),
            .contextMutationAcknowledged(ContextMutationAcknowledgement.failure(failure: .emptyContextName)),
            .contextMutationAcknowledged(ContextMutationAcknowledgement.failure(failure: .contextNotFound(UUID()))),
            .availableContexts(
                AvailableContextsEvent(contexts: [WorkspaceContext(name: "Placeholder", symbol: "book")])
            )
        ]
    )
    func roundTripsThroughJSON(_ event: Event) throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(event)
        let decoded = try decoder.decode(Event.self, from: data)
        #expect(decoded == event)
    }
}
