import Foundation
import Testing
@testable import libdawn

@Suite("EventCodec")
struct EventCodecTests {
    @Test("encode/decode round-trips all cases")
    func roundTripsAllCases() throws {
        let events: [Event] = [
            .debugPing(DebugPingEvent()),
            .debugPong(DebugPongEvent(message: "hello")),
            .switchSpace(SwitchSpaceEvent(spaceIndex: 3))
        ]

        for event in events {
            let decoded = try EventCodec.decode(try EventCodec.encode(event))
            #expect(decoded == event)
        }
    }

    @Test("decode throws on invalid payload")
    func decodeThrowsOnInvalidPayload() {
        #expect(throws: DecodingError.self) {
            _ = try EventCodec.decode(Data("not-json".utf8))
        }
    }
}
