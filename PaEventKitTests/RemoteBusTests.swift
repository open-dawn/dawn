import Foundation
import Testing
@testable import PaEventKit

@MainActor
private final class PingResponder: Listener {
    func handle(_ event: PaEvent, reply: (@Sendable (PaEvent) -> Void)?) {
        guard case .debugPing = event else { return }
        reply?(.debugPong(PaDebugPongEvent(message: "remote-ok")))
    }
}

@MainActor
private final class RecordingListener: Listener {
    private(set) var events: [PaEvent] = []

    func handle(_ event: PaEvent, reply: (@Sendable (PaEvent) -> Void)?) {
        events.append(event)
    }
}

@Suite("Remote Bus")
struct RemoteBusTests {
    @Suite("Loopback")
    struct Loopback {
        @Test @MainActor func publishRoundTrips() async throws {
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

        @Test func askRoundTrips() async throws {
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
    }

    @Suite("XPC")
    struct XPC {
        @Test @MainActor func publishRoundTrips() async throws {
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

        @Test func askRoundTrips() async throws {
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

    @Suite("Host Ask")
    struct HostAsk {
        @Test func throwsNoHandlerWhenOnlyRemoteIsConnected() async {
            let hostBus = PaEventBus()
            let eventServer = PaEventServer(bus: hostBus)
            let link = LoopbackEventLink()
            eventServer.attach(link.server)

            await #expect(throws: PaEventAskError.noHandler) {
                _ = try await hostBus.ask(.debugPing(PaDebugPingEvent()), timeout: .milliseconds(100))
            }

            eventServer.stop()
        }

        @Test @MainActor func throwsNoHandlerWhenRemoteSubscribedToSameKind() async {
            let hostBus = PaEventBus()
            let eventServer = PaEventServer(bus: hostBus)
            let link = LoopbackEventLink()
            eventServer.attach(link.server)

            let remoteBus = PaRemoteEventBus(transport: link.client)
            let listener = RecordingListener()
            remoteBus.addListener(listener, kinds: [.debugPing])

            await #expect(throws: PaEventAskError.noHandler) {
                _ = try await hostBus.ask(.debugPing(PaDebugPingEvent()), timeout: .milliseconds(100))
            }

            remoteBus.disconnect()
            eventServer.stop()
        }
    }

    @Suite("Subscriptions")
    @MainActor
    struct Subscriptions {
        @Test func remoteDoesNotReceiveUnsubscribedKinds() async throws {
            let hostBus = PaEventBus()
            let eventServer = PaEventServer(bus: hostBus)
            let link = LoopbackEventLink()
            eventServer.attach(link.server)

            let remoteBus = PaRemoteEventBus(transport: link.client)
            let listener = RecordingListener()
            remoteBus.addListener(listener, kinds: [.debugPing])

            hostBus.publish(.switchSpace(PaSwitchSpaceEvent(spaceIndex: 1)))
            try await Task.sleep(for: .milliseconds(200))
            #expect(listener.events.isEmpty)

            remoteBus.disconnect()
            eventServer.stop()
        }

        @Test func remoteReceivesSubscribedKindsFromHostPublish() async throws {
            let hostBus = PaEventBus()
            let eventServer = PaEventServer(bus: hostBus)
            let link = LoopbackEventLink()
            eventServer.attach(link.server)

            let remoteBus = PaRemoteEventBus(transport: link.client)
            let listener = RecordingListener()
            remoteBus.addListener(listener, kinds: [.switchSpace])

            let event = PaEvent.switchSpace(PaSwitchSpaceEvent(spaceIndex: 1))
            hostBus.publish(event)
            try await Task.sleep(for: .milliseconds(200))
            #expect(listener.events == [event])

            remoteBus.disconnect()
            eventServer.stop()
        }

        @Test func removeListenerStopsDelivery() async throws {
            let hostBus = PaEventBus()
            let eventServer = PaEventServer(bus: hostBus)
            let link = LoopbackEventLink()
            eventServer.attach(link.server)

            let remoteBus = PaRemoteEventBus(transport: link.client)
            let listener = RecordingListener()
            remoteBus.addListener(listener, kinds: [.switchSpace])

            let event = PaEvent.switchSpace(PaSwitchSpaceEvent(spaceIndex: 1))
            hostBus.publish(event)
            try await Task.sleep(for: .milliseconds(200))
            #expect(listener.events == [event])

            remoteBus.removeListener(listener)
            hostBus.publish(.switchSpace(PaSwitchSpaceEvent(spaceIndex: 2)))
            try await Task.sleep(for: .milliseconds(200))
            #expect(listener.events == [event])

            remoteBus.disconnect()
            eventServer.stop()
        }
    }

    @Suite("Connection")
    struct Connection {
        @Test func askThrowsNotConnectedAfterDisconnect() async {
            let hostBus = PaEventBus()
            let eventServer = PaEventServer(bus: hostBus)
            let link = LoopbackEventLink()
            eventServer.attach(link.server)

            let remoteBus = PaRemoteEventBus(transport: link.client)
            remoteBus.disconnect()

            await #expect(throws: PaEventRemoteError.notConnected) {
                _ = try await remoteBus.ask(.debugPing(PaDebugPingEvent()), timeout: .milliseconds(100))
            }

            eventServer.stop()
        }
    }
}
