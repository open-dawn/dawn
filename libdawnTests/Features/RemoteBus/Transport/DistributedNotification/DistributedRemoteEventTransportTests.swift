import Foundation
import Testing
@testable import libdawn

@Suite("DistributedRemoteEventTransport")
struct DistributedRemoteEventTransportTests {
    @Test("ask round-trips over distributed notifications")
    func askRoundTrips() async throws {
        let fixture = await Fixture()
        defer { fixture.stop() }

        try await fixture.remoteBus.attemptReconnect()
        let reply = try await fixture.remoteBus.ask(
            .debugPing(DebugPingEvent()),
            timeout: .seconds(2)
        )

        #expect(reply == .debugPong(DebugPongEvent(message: "remote-ok")))
    }

    @Test("publish round-trips over distributed notifications")
    @MainActor
    func publishRoundTrips() async throws {
        let fixture = Fixture()
        defer { fixture.stop() }
        let listener = RecordingListener()
        fixture.hostBus.addListener(listener)

        try await fixture.remoteBus.attemptReconnect()
        let event = Event.initialized(InitializedEvent())
        fixture.remoteBus.publish(event)

        let deadline = ContinuousClock.now + .seconds(2)
        while listener.events.isEmpty, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(25))
        }

        #expect(listener.events == [event])
    }

    @Test("stopping the host disconnects the client")
    func hostStopDisconnectsClient() async throws {
        let fixture = await Fixture()
        defer { fixture.remoteBus.disconnect() }

        try await fixture.remoteBus.attemptReconnect()
        fixture.acceptor.stop()
        fixture.eventServer.stop()

        #expect(await waitUntilDisconnected(fixture.remoteBus))
    }

    @Test("ask preserves host errors")
    func askPreservesHostErrors() async throws {
        let fixture = await Fixture(includeResponder: false)
        defer { fixture.stop() }

        try await fixture.remoteBus.attemptReconnect()

        await #expect(throws: EventAskError.noHandler) {
            _ = try await fixture.remoteBus.ask(
                .debugPing(DebugPingEvent()),
                timeout: .seconds(2)
            )
        }
    }
}

private final class Fixture: @unchecked Sendable {
    let hostBus: EventBus
    let eventServer: EventServer
    let acceptor: DistributedRemoteEventTransportAcceptor
    let remoteBus: RemoteEventBus
    private let responder: PingResponder?

    @MainActor
    init(includeResponder: Bool = true) {
        let serviceName = "app.opendawn.tests.distributed.\(UUID().uuidString)"
        let hostBus = EventBus()
        let responder = includeResponder ? PingResponder() : nil
        if let responder {
            hostBus.addListener(responder)
        }

        let eventServer = EventServer(bus: hostBus)
        let acceptor = DistributedRemoteEventTransportAcceptor(
            eventServer: eventServer,
            serviceName: serviceName
        )
        acceptor.start()

        self.hostBus = hostBus
        self.eventServer = eventServer
        self.acceptor = acceptor
        self.responder = responder
        remoteBus = RemoteEventBus(
            transport: DistributedRemoteEventTransportClient(serviceName: serviceName)
        )
    }

    func stop() {
        remoteBus.disconnect()
        acceptor.stop()
        eventServer.stop()
    }
}
