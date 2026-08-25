import Foundation
import Testing
@testable import PaEventKit

@Suite("PaRemoteEventBus")
struct PaRemoteEventBusTests {
    @Suite("Subscriptions")
    @MainActor
    struct Subscriptions {
        @Test("does not receive unsubscribed kinds")
        func remoteDoesNotReceiveUnsubscribedKinds() async throws {
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

        @Test("nil filter receives all kinds from host")
        func remoteReceivesAllKindsWhenListenerHasNoFilter() async throws {
            let hostBus = PaEventBus()
            let eventServer = PaEventServer(bus: hostBus)
            let link = LoopbackEventLink()
            eventServer.attach(link.server)

            let remoteBus = PaRemoteEventBus(transport: link.client)
            let listener = RecordingListener()
            remoteBus.addListener(listener)

            let space = PaEvent.switchSpace(PaSwitchSpaceEvent(spaceIndex: 1))
            let ping = PaEvent.debugPing(PaDebugPingEvent())
            hostBus.publish(space)
            hostBus.publish(ping)
            try await Task.sleep(for: .milliseconds(200))

            #expect(listener.events == [space, ping])

            remoteBus.disconnect()
            eventServer.stop()
        }

        @Test("receives subscribed kinds from host publish")
        func remoteReceivesSubscribedKindsFromHostPublish() async throws {
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

        @Test("removeListener stops remote delivery")
        func removeListenerStopsDelivery() async throws {
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
        @Test("ask throws notConnected after disconnect")
        func askThrowsNotConnectedAfterDisconnect() async {
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

        @Test("isConnected is false after disconnect")
        func isDisconnectedAfterDisconnect() {
            let hostBus = PaEventBus()
            let eventServer = PaEventServer(bus: hostBus)
            let link = LoopbackEventLink()
            eventServer.attach(link.server)

            let remoteBus = PaRemoteEventBus(transport: link.client)
            #expect(remoteBus.isConnected)

            remoteBus.disconnect()

            #expect(!remoteBus.isConnected)
            eventServer.stop()
        }

        @Test("disconnect is idempotent")
        func disconnectIsIdempotent() {
            let hostBus = PaEventBus()
            let eventServer = PaEventServer(bus: hostBus)
            let link = LoopbackEventLink()
            eventServer.attach(link.server)

            let remoteBus = PaRemoteEventBus(transport: link.client)
            remoteBus.disconnect()
            remoteBus.disconnect()

            #expect(!remoteBus.isConnected)
            eventServer.stop()
        }

        @Test("publish after disconnect does not deliver")
        @MainActor
        func publishAfterDisconnectDoesNotDeliver() async throws {
            let hostBus = PaEventBus()
            let hostListener = RecordingListener()
            hostBus.addListener(hostListener)

            let eventServer = PaEventServer(bus: hostBus)
            let link = LoopbackEventLink()
            eventServer.attach(link.server)

            let remoteBus = PaRemoteEventBus(transport: link.client)
            remoteBus.disconnect()
            remoteBus.publish(.switchSpace(PaSwitchSpaceEvent(spaceIndex: 1)))

            try await Task.sleep(for: .milliseconds(200))

            #expect(hostListener.events.isEmpty)
            eventServer.stop()
        }
    }
}
