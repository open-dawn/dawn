import Foundation
@testable import PaEventKit
import Testing

@Suite("PaEvent")
struct PaEventTests {
    @Test("kind matches each event case", arguments: [
        (event: PaEvent.debugPing(PaDebugPingEvent()), kind: PaEventKind.debugPing),
        (event: PaEvent.debugPong(PaDebugPongEvent()), kind: PaEventKind.debugPong),
        (event: PaEvent.switchSpace(PaSwitchSpaceEvent(spaceIndex: 2)), kind: PaEventKind.switchSpace),
        (event: PaEvent.initialized(PaInitializedEvent()), kind: PaEventKind.initialized),
        (event: PaEvent.getContexts(PaGetContextsEvent()), kind: PaEventKind.getContexts),
        (event: PaEvent.contextsFetched(PaContextsFetchedEvent(contexts: [])), kind: PaEventKind.contextsFetched)
    ])
    func exposesKind(_ eventWithKind: (event: PaEvent, kind: PaEventKind)) {
        #expect(eventWithKind.event.kind == eventWithKind.kind)
    }

    @Test("Codable round-trips all cases", arguments: [
        PaEvent.debugPing(PaDebugPingEvent()),
        .debugPong(PaDebugPongEvent(message: "hello")),
        .switchSpace(PaSwitchSpaceEvent(spaceIndex: 3)),
        .initialized(PaInitializedEvent()),
        .getContexts(PaGetContextsEvent()),
        .contextsFetched(PaContextsFetchedEvent(contexts: []))
    ])
    func roundTripsThroughJSON(_ event: PaEvent) throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(event)
        let decoded = try decoder.decode(PaEvent.self, from: data)
        #expect(decoded == event)
    }
}
