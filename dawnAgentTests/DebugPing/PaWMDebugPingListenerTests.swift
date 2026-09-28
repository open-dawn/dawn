import PaEventKit
import Testing

@testable import PaWM

@MainActor
@Suite("PaWMDebugPingListener")
struct PaWMDebugPingListenerTests {
    @Test("Ask debugPing replies with pong")
    func askDebugPingRepliesWithPong() async throws {
        let bus = PaEventBus()
        let ping = PaWMDebugPingListener(bus: bus)

        let reply = try await bus.ask(
            .debugPing(PaDebugPingEvent()),
            timeout: .seconds(1)
        )
        #expect(reply == .debugPong(PaDebugPongEvent(message: "ok")))
        _ = ping
    }
}
