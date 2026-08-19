import Foundation
import Testing
@testable import PaEventKit

@Test func paEventExposesKind() {
    #expect(PaEvent.debugPing(PaDebugPingEvent()).kind == .debugPing)
    #expect(PaEvent.debugPong(PaDebugPongEvent()).kind == .debugPong)
    #expect(PaEvent.switchSpace(PaSwitchSpaceEvent(spaceIndex: 2)).kind == .switchSpace)
}

@Test func paEventRoundTripsThroughJSON() throws {
    let events: [PaEvent] = [
        .debugPing(PaDebugPingEvent()),
        .debugPong(PaDebugPongEvent(message: "hello")),
        .switchSpace(PaSwitchSpaceEvent(spaceIndex: 3)),
    ]

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    for event in events {
        let data = try encoder.encode(event)
        let decoded = try decoder.decode(PaEvent.self, from: data)
        #expect(decoded == event)
    }
}
