import Foundation
import libdawn
import Testing

@Suite("AgentStatus")
struct AgentStatusTests {
    @Test("query returns the debug pong message")
    func queryReturnsPongMessage() async throws {
        let hostBus = EventBus()
        let eventServer = EventServer(bus: hostBus)
        let link = LoopbackEventLink()
        eventServer.attach(link.server)

        let responder = StatusPingResponder()
        hostBus.addListener(responder, kinds: [.debugPing])

        let message = try await AgentStatus.query(
            bus: RemoteEventBus(transport: link.client)
        )

        #expect(message == "ok")
        eventServer.stop()
    }

    @Test("query fails when the agent is unreachable")
    func queryFailsWhenUnreachable() async {
        let bus = RemoteEventBus(transport: RejectingTransport())

        await #expect(throws: AgentError.notConnected) {
            try await AgentStatus.query(bus: bus)
        }
    }

    @Test("query fails when the reply is not a pong")
    func queryFailsWhenReplyIsUnexpected() async {
        let hostBus = EventBus()
        let eventServer = EventServer(bus: hostBus)
        let link = LoopbackEventLink()
        eventServer.attach(link.server)

        let responder = UnexpectedReplyResponder()
        hostBus.addListener(responder, kinds: [.debugPing])

        let bus = RemoteEventBus(transport: link.client)

        await #expect(throws: AgentError.unexpectedResponse(.initialized)) {
            try await AgentStatus.query(bus: bus)
        }

        eventServer.stop()
    }
}

@MainActor
private final class StatusPingResponder: Listener {
    func handle(_ event: Event, reply: (@Sendable (Event) -> Void)?) {
        guard case .debugPing = event else { return }
        reply?(.debugPong(DebugPongEvent(message: "ok")))
    }
}

@MainActor
private final class UnexpectedReplyResponder: Listener {
    func handle(_ event: Event, reply: (@Sendable (Event) -> Void)?) {
        guard case .debugPing = event else { return }
        reply?(.initialized(InitializedEvent()))
    }
}

private final class RejectingTransport: RemoteEventTransportClient, @unchecked Sendable {
    let isConnected = false
    let connectionState: RemoteConnectionState = .disconnected

    func setDeliveryHandler(_ handler: @escaping @Sendable (Event) -> Void) {}

    func setConnectionStateHandler(
        _ handler: (@Sendable (RemoteConnectionState) -> Void)?
    ) {}

    func publish(_ event: Event) {}

    func subscribe(kinds: Set<EventKind>?) {}

    func ask(_ event: Event) async throws -> Event {
        throw EventRemoteError.notConnected
    }

    func attemptReconnect() async throws {
        throw EventRemoteError.notConnected
    }

    func close() {}
}
