import Foundation
import Testing
@testable import PaEventKit

@Suite("XPCRemoteEventTransport")
struct XPCRemoteEventTransportTests {
    @Test("publish round-trips over XPC")
    @MainActor
    func publishRoundTrips() async throws {
        let hostBus = PaEventBus()
        let eventServer = PaEventServer(bus: hostBus)
        let acceptor = XPCRemoteEventTransportAcceptor(eventServer: eventServer)
        acceptor.start()

        guard let endpoint = acceptor.endpoint else {
            Issue.record("Expected anonymous XPC listener endpoint")
            return
        }

        let remoteBus = PaRemoteEventBus(transport: XPCRemoteEventTransportClient(endpoint: endpoint))
        let listener = RecordingListener()
        remoteBus.addListener(listener)

        let event = PaEvent.switchSpace(PaSwitchSpaceEvent(spaceIndex: 4))
        remoteBus.publish(event)

        try await Task.sleep(for: .milliseconds(200))

        #expect(listener.events == [event])

        remoteBus.disconnect()
        acceptor.stop()
        eventServer.stop()
    }

    @Test("ask round-trips over XPC")
    func askRoundTrips() async throws {
        let hostBus = PaEventBus()
        let responder = PingResponder()
        await MainActor.run {
            hostBus.addListener(responder)
        }

        let eventServer = PaEventServer(bus: hostBus)
        let acceptor = XPCRemoteEventTransportAcceptor(eventServer: eventServer)
        acceptor.start()

        guard let endpoint = acceptor.endpoint else {
            Issue.record("Expected anonymous XPC listener endpoint")
            return
        }

        let remoteBus = PaRemoteEventBus(transport: XPCRemoteEventTransportClient(endpoint: endpoint))
        let reply = try await remoteBus.ask(.debugPing(PaDebugPingEvent()), timeout: .seconds(2))

        #expect(reply == .debugPong(PaDebugPongEvent(message: "remote-ok")))

        remoteBus.disconnect()
        acceptor.stop()
        eventServer.stop()
    }
}
