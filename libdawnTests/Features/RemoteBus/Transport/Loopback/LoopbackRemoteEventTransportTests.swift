import Foundation
import Testing
@testable import PaEventKit

@Suite("LoopbackRemoteEventTransport")
struct LoopbackRemoteEventTransportTests {
    @Test("publish round-trips over loopback")
    @MainActor
    func publishRoundTrips() async throws {
        let hostBus = PaEventBus()
        let eventServer = PaEventServer(bus: hostBus)
        let link = LoopbackEventLink()
        eventServer.attach(link.server)

        let remoteBus = PaRemoteEventBus(transport: link.client)
        let listener = RecordingListener()
        remoteBus.addListener(listener)

        let event = PaEvent.switchSpace(PaSwitchSpaceEvent(spaceIndex: 4))
        remoteBus.publish(event)

        try await Task.sleep(for: .milliseconds(200))

        #expect(listener.events == [event])

        remoteBus.disconnect()
        eventServer.stop()
    }

    @Test("ask round-trips over loopback")
    func askRoundTrips() async throws {
        let hostBus = PaEventBus()
        let responder = PingResponder()
        await MainActor.run {
            hostBus.addListener(responder)
        }

        let eventServer = PaEventServer(bus: hostBus)
        let link = LoopbackEventLink()
        eventServer.attach(link.server)

        let remoteBus = PaRemoteEventBus(transport: link.client)
        let reply = try await remoteBus.ask(.debugPing(PaDebugPingEvent()), timeout: .seconds(2))

        #expect(reply == .debugPong(PaDebugPongEvent(message: "remote-ok")))

        remoteBus.disconnect()
        eventServer.stop()
    }

    @Test("ask throws notConnected after close")
    func askThrowsNotConnectedAfterClose() async {
        let link = LoopbackEventLink()
        link.client.close()

        await #expect(throws: PaEventRemoteError.notConnected) {
            _ = try await link.client.ask(.debugPing(PaDebugPingEvent()))
        }
    }

    @Test("close is idempotent")
    func closeIsIdempotent() {
        let link = LoopbackEventLink()
        link.client.close()
        link.client.close()

        #expect(!link.client.isConnected)
    }

    @Test("isConnected is false after close")
    func isConnectedFalseAfterClose() {
        let link = LoopbackEventLink()
        #expect(link.client.isConnected)

        link.client.close()

        #expect(!link.client.isConnected)
    }

    @Test("host deliver after close does not reach client")
    func publishAfterCloseDoesNotDeliver() {
        final class DeliveryBox: @unchecked Sendable {
            private let lock = NSLock()
            private var events: [PaEvent] = []

            func append(_ event: PaEvent) {
                lock.withLock { events.append(event) }
            }

            func snapshot() -> [PaEvent] {
                lock.withLock { events }
            }
        }

        let link = LoopbackEventLink()
        let delivered = DeliveryBox()

        link.client.setDeliveryHandler { event in
            delivered.append(event)
        }

        link.client.close()
        link.server.deliver(.switchSpace(PaSwitchSpaceEvent(spaceIndex: 1)))

        #expect(delivered.snapshot().isEmpty)
    }

    @Test("ask throws notConnected when server has no handler")
    func askThrowsNotConnectedWhenServerHasNoAskHandler() async {
        let link = LoopbackEventLink()

        await #expect(throws: PaEventRemoteError.notConnected) {
            _ = try await link.client.ask(.debugPing(PaDebugPingEvent()))
        }
    }
}
