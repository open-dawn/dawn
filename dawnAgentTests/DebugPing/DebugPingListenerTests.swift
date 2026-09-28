import libdawn
import Testing

@testable import dawnAgent

@MainActor
@Suite("DebugPingListener")
struct DebugPingListenerTests {
    @Test("Ask debugPing replies with pong")
    func askDebugPingRepliesWithPong() async throws {
        let bus = EventBus()
        let ping = DebugPingListener(bus: bus)

        let reply = try await bus.ask(
            .debugPing(DebugPingEvent()),
            timeout: .seconds(1)
        )
        #expect(reply == .debugPong(DebugPongEvent(message: "ok")))
        _ = ping
    }
}
