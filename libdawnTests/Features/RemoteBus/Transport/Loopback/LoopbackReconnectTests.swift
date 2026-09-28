import Foundation
import Testing
@testable import libdawn

@Suite("Loopback reconnect")
struct LoopbackReconnectTests {
    @Test("attemptReconnect restores delivery and subscriptions")
    @MainActor
    func reconnectRestoresDelivery() async throws {
        let hostBus = PaEventBus()
        let eventServer = PaEventServer(bus: hostBus)
        let link = LoopbackEventLink()
        eventServer.attach(link.server)

        let remoteBus = PaRemoteEventBus(transport: link.client)
        let listener = RecordingListener()
        remoteBus.addListener(listener, kinds: [.switchSpace])

        link.client.simulateDisconnect()
        #expect(!remoteBus.isConnected)

        try await remoteBus.attemptReconnect()
        #expect(remoteBus.isConnected)

        let event = PaEvent.switchSpace(PaSwitchSpaceEvent(spaceIndex: 2))
        hostBus.publish(event)
        try await Task.sleep(for: .milliseconds(200))

        #expect(listener.events == [event])

        remoteBus.disconnect()
        eventServer.stop()
    }

    @Test("connection state handler reports disconnect and reconnect")
    func connectionStateHandlerReportsTransitions() async throws {
        let link = LoopbackEventLink()
        let remoteBus = PaRemoteEventBus(transport: link.client)

        let states = ConnectionStateCapture()
        remoteBus.setConnectionStateHandler { state in
            Task { await states.record(state) }
        }

        link.client.simulateDisconnect()
        try await remoteBus.attemptReconnect()

        try await Task.sleep(for: .milliseconds(100))

        let recorded = await states.snapshot()
        #expect(recorded.contains(.disconnected))
        #expect(recorded.contains(.connected))

        remoteBus.disconnect()
    }

    @Test("close is terminal and attemptReconnect throws")
    func closeIsTerminal() async {
        let link = LoopbackEventLink()
        link.client.close()

        await #expect(throws: PaEventRemoteError.notConnected) {
            try await link.client.attemptReconnect()
        }
    }
}

private actor ConnectionStateCapture {
    private var states: [PaRemoteConnectionState] = []

    func record(_ state: PaRemoteConnectionState) {
        states.append(state)
    }

    func snapshot() -> [PaRemoteConnectionState] {
        states
    }
}
