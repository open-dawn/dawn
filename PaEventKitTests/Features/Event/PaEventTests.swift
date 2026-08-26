import Foundation
import Testing
@testable import PaEventKit

@Suite("PaEvent")
struct PaEventTests {
    @Test("kind matches each event case")
    func exposesKind() {
        #expect(PaEvent.debugPing(PaDebugPingEvent()).kind == .debugPing)
        #expect(PaEvent.debugPong(PaDebugPongEvent()).kind == .debugPong)
        #expect(PaEvent.switchSpace(PaSwitchSpaceEvent(spaceIndex: 2)).kind == .switchSpace)
    }

    @Test("Codable round-trips all cases")
    func roundTripsThroughJSON() throws {
        let events: [PaEvent] = [
            .debugPing(PaDebugPingEvent()),
            .debugPong(PaDebugPongEvent(message: "hello")),
            .switchSpace(PaSwitchSpaceEvent(spaceIndex: 3))
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
