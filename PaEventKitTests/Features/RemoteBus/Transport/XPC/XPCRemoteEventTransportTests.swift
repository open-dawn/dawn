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

        guard await waitUntilConnected(remoteBus) else {
            Issue.record("Expected XPC handshake to succeed")
            return
        }

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
        guard await waitUntilConnected(remoteBus) else {
            Issue.record("Expected XPC handshake to succeed")
            return
        }

        let reply = try await remoteBus.ask(.debugPing(PaDebugPingEvent()), timeout: .seconds(2))

        #expect(reply == .debugPong(PaDebugPongEvent(message: "remote-ok")))

        remoteBus.disconnect()
        acceptor.stop()
        eventServer.stop()
    }

    @Test("host stop leaves the client disconnected")
    func hostStopLeavesClientDisconnected() async throws {
        let hostBus = PaEventBus()
        let eventServer = PaEventServer(bus: hostBus)
        let acceptor = XPCRemoteEventTransportAcceptor(eventServer: eventServer)
        acceptor.start()

        guard let endpoint = acceptor.endpoint else {
            Issue.record("Expected anonymous XPC listener endpoint")
            return
        }

        let remoteBus = PaRemoteEventBus(transport: XPCRemoteEventTransportClient(endpoint: endpoint))
        defer { remoteBus.disconnect() }

        guard await waitUntilConnected(remoteBus) else {
            Issue.record("Expected XPC handshake to succeed")
            return
        }

        acceptor.stop()
        eventServer.stop()

        #expect(await waitUntilDisconnected(remoteBus))
        await #expect(throws: PaEventRemoteError.notConnected) {
            try await remoteBus.attemptReconnect()
        }
    }

    @Test("missing mach service stays disconnected")
    func missingMachServiceStaysDisconnected() async throws {
        let transport = XPCRemoteEventTransportClient(
            machServiceName: "dev.longhi.pineappleinc.missing.\(UUID().uuidString)"
        )
        // Snapshot before wrapping so an optimistic connected flash during init is not missed.
        var sawConnected = transport.isConnected || transport.connectionState == .connected
        let remoteBus = PaRemoteEventBus(transport: transport)
        defer { remoteBus.disconnect() }

        // Wait through the handshake timeout so a late connected cannot slip through.
        let deadline = ContinuousClock.now + .seconds(2.5)
        while ContinuousClock.now < deadline {
            if remoteBus.isConnected || remoteBus.connectionState == .connected {
                sawConnected = true
                break
            }
            try await Task.sleep(for: .milliseconds(50))
        }

        #expect(!sawConnected)
        #expect(remoteBus.connectionState != .connected)
        #expect(!remoteBus.isConnected)
    }

    @Test("stale invalidation does not drop a newer connection")
    func staleInvalidationDoesNotDropNewerConnection() async throws {
        let hostBus = PaEventBus()
        let eventServer = PaEventServer(bus: hostBus)
        let acceptor = XPCRemoteEventTransportAcceptor(eventServer: eventServer)
        acceptor.start()
        defer {
            acceptor.stop()
            eventServer.stop()
        }

        guard let endpoint = acceptor.endpoint else {
            Issue.record("Expected anonymous XPC listener endpoint")
            return
        }

        let transport = XPCRemoteEventTransportClient(endpoint: endpoint)
        let remoteBus = PaRemoteEventBus(transport: transport)
        defer { remoteBus.disconnect() }

        guard await waitUntilConnected(remoteBus) else {
            Issue.record("Expected XPC handshake to succeed")
            return
        }

        let staleGeneration = transport.currentGeneration()
        try await remoteBus.attemptReconnect()

        guard await waitUntilConnected(remoteBus) else {
            Issue.record("Expected reconnect handshake to succeed")
            return
        }

        #expect(transport.currentGeneration() != staleGeneration)

        transport.handleInvalidation(generation: staleGeneration)
        transport.handleInterruption(generation: staleGeneration)

        #expect(remoteBus.isConnected)
    }

    @Test("An older reconnect cannot tear down a newer connection")
    func olderReconnectCantTearDownNewerConnection() async throws {
        let hostBus = PaEventBus()
        let responder = PingResponder()

        await MainActor.run {
            hostBus.addListener(responder)
        }

        let eventServer = PaEventServer(bus: hostBus)
        let acceptor = XPCRemoteEventTransportAcceptor(eventServer: eventServer)
        acceptor.start()

        defer {
            acceptor.stop()
            eventServer.stop()
        }

        guard let endpoint = acceptor.endpoint else {
            Issue.record("Expected anonymous XPC Listener endpoint")
            return
        }

        let transport = XPCRemoteEventTransportClient(endpoint: endpoint)
        let remoteBus = PaRemoteEventBus(transport: transport)
        let gate = FirstConnectingGate()

        defer {
            gate.release()
            transport.setConnectionStateHandler(nil)
            remoteBus.disconnect()
        }

        guard await waitUntilConnected(remoteBus) else {
            Issue.record("Expected initial XPC handshake to succeed")
            return
        }

        transport.setConnectionStateHandler { state in
            gate.handle(state)
        }

        let olderReconnect = Task {
            try? await transport.attemptReconnect()
        }

        guard await gate.waitUntilPaused() else {
            Issue.record("Older reconnect did not reach the connecting state")
            gate.release()
            _ = await olderReconnect.value
            return
        }

        let newerReconnect = Task {
            try await transport.attemptReconnect()
        }

        do {
            try await newerReconnect.value
        } catch {
            Issue.record("Newer reconnect unexpectedly failed: \(error)")
            gate.release()
            _ = await olderReconnect.value
            return
        }

        #expect(transport.connectionState == .connected)

        gate.release()
        _ = await olderReconnect.value

        do {
            let reply = try await transport.ask(
                .debugPing(PaDebugPingEvent())
            )

            #expect(
                reply == .debugPong(
                    PaDebugPongEvent(message: "remote-ok")
                )
            )
        } catch {
            Issue.record(
                "The older reconnect tore down the newer connection: \(error)"
            )
        }
    }
}

private final class FirstConnectingGate: @unchecked Sendable {
    private let lock = NSLock()
    private let resumeSemaphore = DispatchSemaphore(value: 0)

    private var didPause = false
    private var isPaused = false
    private var wasReleased = false

    func handle(_ state: PaRemoteConnectionState) {
        guard state == .connecting else { return }

        let shouldPause = lock.withLock {
            guard !didPause else { return false }

            didPause = true
            isPaused = true
            return true
        }

        guard shouldPause else { return }

        resumeSemaphore.wait()
    }

    func waitUntilPaused(
        timeout: Duration = .seconds(2)
    ) async -> Bool {
        let deadline = ContinuousClock.now + timeout

        while ContinuousClock.now < deadline {
            if lock.withLock({ isPaused }) {
                return true
            }

            try? await Task.sleep(for: .milliseconds(10))
        }

        return lock.withLock { isPaused }
    }

    func release() {
        let shouldSignal = lock.withLock {
            guard !wasReleased else { return false }

            wasReleased = true

            return true
        }

        if shouldSignal {
            resumeSemaphore.signal()
        }
    }
}
