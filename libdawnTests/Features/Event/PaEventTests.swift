import Foundation
import Testing

@testable import libdawn

@Suite("PaEvent")
struct PaEventTests {
    @Test(
        "kind matches each event case",
        arguments: [
            (event: PaEvent.debugPing(PaDebugPingEvent()), kind: PaEventKind.debugPing),
            (event: PaEvent.debugPong(PaDebugPongEvent()), kind: PaEventKind.debugPong),
            (event: PaEvent.switchSpace(PaSwitchSpaceEvent(spaceIndex: 2)), kind: PaEventKind.switchSpace),
            (event: PaEvent.initialized(PaInitializedEvent()), kind: PaEventKind.initialized),
            (event: PaEvent.getContexts(PaGetContextsEvent()), kind: PaEventKind.getContexts),
            (event: PaEvent.contextsFetched(PaContextsFetchedEvent(contexts: [])), kind: PaEventKind.contextsFetched),
            (
                event: PaEvent.availableContexts(PaAvailableContextsEvent(contexts: [])),
                kind: PaEventKind.availableContexts
            ),
            (
                event: PaEvent.createContext(
                    PaCreateContextEvent(name: "placeholder", symbol: "book", applications: [])
                ),
                kind: PaEventKind.createContext
            ),
            (
                event: PaEvent.updateContext(
                    PaUpdateContextEvent(
                        context: WorkspaceContext(name: "placeholder", symbol: "book")
                    )
                ),
                kind: PaEventKind.updateContext
            ),
            (event: PaEvent.deleteContext(PaDeleteContextEvent(contextID: UUID())), kind: PaEventKind.deleteContext),
            (
                event: PaEvent.switchContext(PaSwitchContextEvent(contextID: UUID())),
                kind: PaEventKind.switchContext
            ),
            (
                event: PaEvent.contextMutationAcknowledged(.success(contextID: UUID())),
                kind: PaEventKind.contextMutationAcknowledged
            ),
        ]
    )
    func exposesKind(_ eventWithKind: (event: PaEvent, kind: PaEventKind)) {
        #expect(eventWithKind.event.kind == eventWithKind.kind)
    }

    @Test(
        "Codable round-trips all cases",
        arguments: [
            PaEvent.debugPing(PaDebugPingEvent()),
            .debugPong(PaDebugPongEvent(message: "hello")),
            .switchSpace(PaSwitchSpaceEvent(spaceIndex: 3)),
            .initialized(PaInitializedEvent()),
            .getContexts(PaGetContextsEvent()),
            .contextsFetched(PaContextsFetchedEvent(contexts: [])),
            .createContext(PaCreateContextEvent(name: "placeholder", symbol: "book", applications: [])),
            .updateContext(PaUpdateContextEvent(context: WorkspaceContext(name: "placeholder", symbol: "book"))),
            .deleteContext(PaDeleteContextEvent(contextID: UUID())),
            .switchContext(PaSwitchContextEvent(contextID: UUID())),
            .contextMutationAcknowledged(PaContextMutationAcknowledgement.success(contextID: UUID())),
            .contextMutationAcknowledged(PaContextMutationAcknowledgement.failure(failure: .emptyContextName)),
            .contextMutationAcknowledged(PaContextMutationAcknowledgement.failure(failure: .contextNotFound(UUID()))),
            .availableContexts(
                PaAvailableContextsEvent(contexts: [WorkspaceContext(name: "Placeholder", symbol: "book")])
            )
        ]
    )
    func roundTripsThroughJSON(_ event: PaEvent) throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(event)
        let decoded = try decoder.decode(PaEvent.self, from: data)
        #expect(decoded == event)
    }
}
