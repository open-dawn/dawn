import Foundation
import Testing
@testable import libdawn

@Suite("PaEventCodec")
struct PaEventCodecTests {
    @Test("encode/decode round-trips all cases")
    func roundTripsAllCases() throws {
        let events: [PaEvent] = [
            .debugPing(PaDebugPingEvent()),
            .debugPong(PaDebugPongEvent(message: "hello")),
            .switchSpace(PaSwitchSpaceEvent(spaceIndex: 3))
        ]

        for event in events {
            let decoded = try PaEventCodec.decode(try PaEventCodec.encode(event))
            #expect(decoded == event)
        }
    }

    @Test("decode throws on invalid payload")
    func decodeThrowsOnInvalidPayload() {
        #expect(throws: DecodingError.self) {
            _ = try PaEventCodec.decode(Data("not-json".utf8))
        }
    }
}
