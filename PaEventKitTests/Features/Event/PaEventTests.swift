import Foundation
@testable import PaEventKit
import Testing

@Suite("PaEvent")
struct PaEventTests {
    @Test("kind matches each event case")
    func exposesKind() {
        #expect(PaEvent.debugPing(PaDebugPingEvent()).kind == .debugPing)
        #expect(PaEvent.debugPong(PaDebugPongEvent()).kind == .debugPong)
        #expect(PaEvent.switchSpace(PaSwitchSpaceEvent(spaceIndex: 2)).kind == .switchSpace)
        #expect(PaEvent.initialized(PaInitializedEvent()).kind == .initialized)
        #expect(PaEvent.getContexts(PaGetContextsEvent()).kind == .getContexts)
        #expect(PaEvent.contextsFetched(PaContextsFetchedEvent(contexts: [])).kind == .contextsFetched)
    }

    @Test("Codable round-trips all cases")
    func roundTripsThroughJSON() throws {
        let events: [PaEvent] = [
            .debugPing(PaDebugPingEvent()),
            .debugPong(PaDebugPongEvent(message: "hello")),
            .switchSpace(PaSwitchSpaceEvent(spaceIndex: 3)),
            .initialized(PaInitializedEvent()),
            .getContexts(PaGetContextsEvent()),
            .contextsFetched(PaContextsFetchedEvent(contexts: []))
        ]

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for event in events {
            let data = try encoder.encode(event)
            let decoded = try decoder.decode(PaEvent.self, from: data)
            #expect(decoded == event)
        }
    }
}
