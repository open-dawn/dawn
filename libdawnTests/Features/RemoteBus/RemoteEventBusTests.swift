import Foundation
import Testing
@testable import libdawn

@Suite("RemoteEventBus")
struct RemoteEventBusTests {
    @Suite("Subscriptions")
    @MainActor
    struct Subscriptions {
        @Test("does not receive unsubscribed kinds")
        func remoteDoesNotReceiveUnsubscribedKinds() async throws {
            let hostBus = EventBus()
            let eventServer = EventServer(bus: hostBus)
            let link = LoopbackEventLink()
            eventServer.attach(link.server)

            let remoteBus = RemoteEventBus(transport: link.client)
            let listener = RecordingListener()
            remoteBus.addListener(listener, kinds: [.debugPing])

            hostBus.publish(.switchSpace(SwitchSpaceEvent(spaceIndex: 1)))
            try await Task.sleep(for: .milliseconds(200))

            #expect(listener.events.isEmpty)

            remoteBus.disconnect()
            eventServer.stop()
        }

        @Test("nil filter receives all kinds from host")
        func remoteReceivesAllKindsWhenListenerHasNoFilter() async throws {
            let hostBus = EventBus()
            let eventServer = EventServer(bus: hostBus)
            let link = LoopbackEventLink()
            eventServer.attach(link.server)

            let remoteBus = RemoteEventBus(transport: link.client)
            let listener = RecordingListener()
            remoteBus.addListener(listener)

            let space = Event.switchSpace(SwitchSpaceEvent(spaceIndex: 1))
            let ping = Event.debugPing(DebugPingEvent())
            hostBus.publish(space)
            hostBus.publish(ping)
            try await Task.sleep(for: .milliseconds(200))

            #expect(listener.events == [space, ping])

            remoteBus.disconnect()
            eventServer.stop()
        }

        @Test("receives subscribed kinds from host publish")
        func remoteReceivesSubscribedKindsFromHostPublish() async throws {
            let hostBus = EventBus()
            let eventServer = EventServer(bus: hostBus)
            let link = LoopbackEventLink()
            eventServer.attach(link.server)

            let remoteBus = RemoteEventBus(transport: link.client)
            let listener = RecordingListener()
            remoteBus.addListener(listener, kinds: [.switchSpace])

            let event = Event.switchSpace(SwitchSpaceEvent(spaceIndex: 1))
            hostBus.publish(event)
            try await Task.sleep(for: .milliseconds(200))

            #expect(listener.events == [event])

            remoteBus.disconnect()
            eventServer.stop()
        }

        @Test("removeListener stops remote delivery")
        func removeListenerStopsDelivery() async throws {
            let hostBus = EventBus()
            let eventServer = EventServer(bus: hostBus)
            let link = LoopbackEventLink()
            eventServer.attach(link.server)

            let remoteBus = RemoteEventBus(transport: link.client)
            let listener = RecordingListener()
            remoteBus.addListener(listener, kinds: [.switchSpace])

            let event = Event.switchSpace(SwitchSpaceEvent(spaceIndex: 1))
            hostBus.publish(event)
            try await Task.sleep(for: .milliseconds(200))

            #expect(listener.events == [event])

            remoteBus.removeListener(listener)
            hostBus.publish(.switchSpace(SwitchSpaceEvent(spaceIndex: 2)))
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
            let hostBus = EventBus()
            let eventServer = EventServer(bus: hostBus)
            let link = LoopbackEventLink()
            eventServer.attach(link.server)

            let remoteBus = RemoteEventBus(transport: link.client)
            remoteBus.disconnect()

            await #expect(throws: EventRemoteError.notConnected) {
                _ = try await remoteBus.ask(.debugPing(DebugPingEvent()), timeout: .milliseconds(100))
            }

            eventServer.stop()
        }

        @Test("isConnected is false after disconnect")
        func isDisconnectedAfterDisconnect() {
            let hostBus = EventBus()
            let eventServer = EventServer(bus: hostBus)
            let link = LoopbackEventLink()
            eventServer.attach(link.server)

            let remoteBus = RemoteEventBus(transport: link.client)
            #expect(remoteBus.isConnected)

            remoteBus.disconnect()

            #expect(!remoteBus.isConnected)
            eventServer.stop()
        }

        @Test("disconnect is idempotent")
        func disconnectIsIdempotent() {
            let hostBus = EventBus()
            let eventServer = EventServer(bus: hostBus)
            let link = LoopbackEventLink()
            eventServer.attach(link.server)

            let remoteBus = RemoteEventBus(transport: link.client)
            remoteBus.disconnect()
            remoteBus.disconnect()

            #expect(!remoteBus.isConnected)
            eventServer.stop()
        }

        @Test("publish after disconnect does not deliver")
        @MainActor
        func publishAfterDisconnectDoesNotDeliver() async throws {
            let hostBus = EventBus()
            let hostListener = RecordingListener()
            hostBus.addListener(hostListener)

            let eventServer = EventServer(bus: hostBus)
            let link = LoopbackEventLink()
            eventServer.attach(link.server)

            let remoteBus = RemoteEventBus(transport: link.client)
            remoteBus.disconnect()
            remoteBus.publish(.switchSpace(SwitchSpaceEvent(spaceIndex: 1)))

            try await Task.sleep(for: .milliseconds(200))

            #expect(hostListener.events.isEmpty)
            eventServer.stop()
        }
    }
}
