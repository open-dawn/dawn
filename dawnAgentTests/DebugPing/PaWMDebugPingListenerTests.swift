import libdawn
import Testing

@testable import dawnAgent

@MainActor
@Suite("dawnAgentDebugPingListener")
struct dawnAgentDebugPingListenerTests {
    @Test("Ask debugPing replies with pong")
    func askDebugPingRepliesWithPong() async throws {
        let bus = PaEventBus()
        let ping = dawnAgentDebugPingListener(bus: bus)

        let reply = try await bus.ask(
            .debugPing(PaDebugPingEvent()),
            timeout: .seconds(1)
        )
        #expect(reply == .debugPong(PaDebugPongEvent(message: "ok")))
        _ = ping
    }
}
