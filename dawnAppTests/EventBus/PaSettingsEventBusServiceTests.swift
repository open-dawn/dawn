import Foundation
import Testing

@testable import PaEventKit
@testable import PaSettingsUI

@MainActor
@Suite("PaSettingsEventBusService")
struct PaSettingsEventBusServiceTests {
    @Test("Start connects and publishes connection state")
    func startConnects() async throws {
        let fixture = ServiceFixture()
        defer { fixture.cleanUp() }

        fixture.service.start()

        try await Task.sleep(for: .milliseconds(200))

        #expect(fixture.service.isConnected)
        #expect(fixture.service.bus.isConnected)
    }

    @Test("Ready ping triggers reconnect after a failed attempt")
    func readyPingReconnects() async throws {
        let fixture = ServiceFixture()
        defer { fixture.cleanUp() }

        fixture.service.start()
        try await Task.sleep(for: .milliseconds(200))
        #expect(fixture.service.isConnected)

        fixture.transport.allowReconnect = false
        fixture.link.client.simulateDisconnect()
        try await Task.sleep(for: .milliseconds(300))
        #expect(!fixture.service.isConnected)

        fixture.transport.allowReconnect = true

        DistributedNotificationCenter.default().postNotificationName(
            fixture.readyNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )

        try await Task.sleep(for: .milliseconds(300))

        #expect(fixture.service.isConnected)
    }

    @Test("Drop from connected triggers one reconnect")
    func dropFromConnectedReconnects() async throws {
        let fixture = ServiceFixture()
        defer { fixture.cleanUp() }

        fixture.service.start()
        try await Task.sleep(for: .milliseconds(200))
        #expect(fixture.service.isConnected)

        let bus = fixture.service.bus

        fixture.link.client.simulateDisconnect()
        try await Task.sleep(for: .milliseconds(300))

        #expect(fixture.service.bus === bus)
        #expect(fixture.service.isConnected)
        #expect(fixture.service.bus.isConnected)
    }

    @Test("Failed drop does not retry until the ready ping")
    func failedDropDoesNotSpin() async throws {
        let fixture = ServiceFixture()
        defer { fixture.cleanUp() }

        fixture.service.start()
        try await Task.sleep(for: .milliseconds(200))
        #expect(fixture.service.isConnected)

        fixture.transport.allowReconnect = false
        fixture.link.client.simulateDisconnect()
        try await Task.sleep(for: .milliseconds(300))

        #expect(!fixture.service.isConnected)
        let attempts = fixture.transport.reconnectAttempts

        try await Task.sleep(for: .milliseconds(400))

        #expect(!fixture.service.isConnected)
        #expect(fixture.transport.reconnectAttempts == attempts)
        #expect(attempts == 1)
    }

    @Test("Reconnect publishes connecting")
    func reconnectPublishesConnecting() async throws {
        let fixture = ServiceFixture()
        defer { fixture.cleanUp() }

        fixture.service.start()
        try await Task.sleep(for: .milliseconds(200))
        #expect(fixture.service.connectionState == .connected)

        fixture.transport.pauseInConnecting = true
        fixture.link.client.simulateDisconnect()

        var sawConnecting = fixture.service.connectionState == .connecting
        for _ in 0..<40 where !sawConnecting {
            try await Task.sleep(for: .milliseconds(50))
            sawConnecting = fixture.service.connectionState == .connecting
        }
        #expect(sawConnecting)

        fixture.transport.resumeReconnect()
        try await Task.sleep(for: .milliseconds(200))

        #expect(fixture.service.connectionState == .connected)
    }

    @Test("Stop ignores later ready pings")
    func stopIgnoresReadyPing() async throws {
        let fixture = ServiceFixture()
        defer { fixture.cleanUp() }

        fixture.service.start()
        try await Task.sleep(for: .milliseconds(200))
        #expect(fixture.service.isConnected)

        fixture.service.stop()

        DistributedNotificationCenter.default().postNotificationName(
            fixture.readyNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )

        try await Task.sleep(for: .milliseconds(200))

        #expect(!fixture.service.isConnected)
    }

    @Test("Listener survives reconnect")
    func listenerSurvivesReconnect() async throws {
        let fixture = ServiceFixture()
        defer { fixture.cleanUp() }

        let listener = RecordingListener()
        fixture.service.bus.addListener(listener, kinds: [.switchSpace])
        fixture.service.start()

        try await Task.sleep(for: .milliseconds(200))

        fixture.link.client.simulateDisconnect()
        try await fixture.service.bus.attemptReconnect()
        try await Task.sleep(for: .milliseconds(100))

        let event = PaEvent.switchSpace(PaSwitchSpaceEvent(spaceIndex: 7))
        fixture.hostBus.publish(event)
        try await Task.sleep(for: .milliseconds(200))

        #expect(listener.events == [event])
    }

    @Test("Stop ignores and already queued connection callback")
    func stopIgnoresQueuedConnectionCallback() async throws {
        let fixture = ServiceFixture()
        defer { fixture.cleanUp() }

        fixture.service.start()

        #expect(fixture.service.isConnected)

        fixture.transport.emitConnectionState(.connected)

        fixture.service.stop()

        #expect(!fixture.service.isConnected)
        #expect(fixture.service.connectionState == .disconnected)

        await Task.yield()

        #expect(!fixture.service.isConnected)
        #expect(fixture.service.connectionState == .disconnected)
        #expect(!fixture.service.bus.isConnected)
    }

    @Test("Ready ping during a failing reconnect triggers a follow-up attempt")
    func readyPingDuringReconnectIsNotLost() async throws {
        let fixture = ServiceFixture()
        defer { fixture.cleanUp() }

        fixture.service.start()

        #expect(fixture.service.isConnected)

        fixture.transport.pauseThenFailNextReconnect()

        defer {
            fixture.transport.resumeReconnect()
        }

        fixture.link.client.simulateDisconnect()

        guard await fixture.transport.waitUntilReconnectIsPaused() else {
            Issue.record("The first reconnect did not pause")
            return
        }

        #expect(fixture.transport.reconnectAttempts == 1)

        DistributedNotificationCenter.default().postNotificationName(
            fixture.readyNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )

        try await Task.sleep(for: .milliseconds(50))

        #expect(fixture.transport.reconnectAttempts == 1)

        fixture.transport.resumeReconnect()

        let deadline = ContinuousClock.now + .seconds(1)

        while ContinuousClock.now < deadline {
            if fixture.transport.reconnectAttempts == 2,
               fixture.service.isConnected {
                break
            }

            await Task.yield()
        }

        #expect(fixture.transport.reconnectAttempts == 2)
        #expect(fixture.service.isConnected)
        #expect(fixture.service.bus.isConnected)
    }
}

@MainActor
private struct ServiceFixture {
    let readyNotification: Notification.Name
    let link: LoopbackEventLink
    let transport: ControllableLoopbackTransport
    let hostBus: PaEventBus
    let service: PaSettingsEventBusService
    private let eventServer: PaEventServer

    init() {
        let readyNotification = Notification.Name(
            "PaSettingsEventBusServiceTests.\(UUID().uuidString).ready"
        )
        let hostBus = PaEventBus()
        let eventServer = PaEventServer(bus: hostBus)
        let link = LoopbackEventLink()
        eventServer.attach(link.server)
        let transport = ControllableLoopbackTransport(client: link.client)
        let readyObserver = PaSettingsEventBusReadyObserver(notificationName: readyNotification)

        self.readyNotification = readyNotification
        self.link = link
        self.transport = transport
        self.hostBus = hostBus
        self.eventServer = eventServer
        self.service = PaSettingsEventBusService(
            transport: transport,
            readyObserver: readyObserver
        )
    }

    func cleanUp() {
        service.stop()
        eventServer.stop()
    }
}

private final class ControllableLoopbackTransport: RemoteEventTransportClient, @unchecked Sendable {
    private let client: LoopbackRemoteEventTransportClient
    private let lock = NSLock()
    private var reconnectResume: CheckedContinuation<Void, Never>?

    var allowReconnect = true
    var pauseInConnecting = false
    private(set) var storedReconnectAttempts = 0

    var reconnectAttempts: Int {
        lock.withLock {
            storedReconnectAttempts
        }
    }

    private var shouldPauseThenFailNextReconnect = false

    private var connectionStateHandler: (@Sendable (PaRemoteConnectionState) -> Void)?

    init(client: LoopbackRemoteEventTransportClient) {
        self.client = client
    }

    var isConnected: Bool { client.isConnected }
    var connectionState: PaRemoteConnectionState { client.connectionState }

    func setDeliveryHandler(_ handler: @escaping @Sendable (PaEvent) -> Void) {
        client.setDeliveryHandler(handler)
    }

    func setConnectionStateHandler(
        _ handler: (@Sendable (PaRemoteConnectionState) -> Void)?
    ) {
        lock.withLock {
            connectionStateHandler = handler
        }

        client.setConnectionStateHandler(handler)
    }

    func pauseThenFailNextReconnect() {
        lock.withLock {
            shouldPauseThenFailNextReconnect = true
        }
    }

    func publish(_ event: PaEvent) {
        client.publish(event)
    }

    func subscribe(kinds: Set<PaEventKind>?) {
        client.subscribe(kinds: kinds)
    }

    func ask(_ event: PaEvent) async throws -> PaEvent {
        try await client.ask(event)
    }

    func attemptReconnect() async throws {
        let pauseThenFail = lock.withLock {
            storedReconnectAttempts += 1

            guard shouldPauseThenFailNextReconnect else {
                return false
            }

            shouldPauseThenFailNextReconnect = false
            return true
        }

        guard allowReconnect else {
            throw PaEventRemoteError.notConnected
        }

        if pauseThenFail {
            emitConnectionState(.connecting)

            await suspendedReconnect()

            throw PaEventRemoteError.notConnected
        }

        client.simulateConnecting()

        if pauseInConnecting {
            await suspendedReconnect()
        }

        try await client.attemptReconnect()
    }

    func resumeReconnect() {
        let continuation = lock.withLock { () -> CheckedContinuation<Void, Never>? in
            defer { reconnectResume = nil }
            return reconnectResume
        }
        continuation?.resume()
    }

    func close() {
        client.close()
    }

    func emitConnectionState(_ state: PaRemoteConnectionState) {
        let handler = lock.withLock {
            connectionStateHandler
        }

        handler?(state)
    }

    func waitUntilReconnectIsPaused(
        timeout: Duration = .seconds(
            2
        )
    ) async -> Bool {
        let deadline = ContinuousClock.now + timeout

        while ContinuousClock.now < deadline {
            if lock.withLock({ reconnectResume != nil }) {
                return true
            }

            try? await Task.sleep(for: .milliseconds(10))
        }

        return lock.withLock {
            reconnectResume != nil
        }
    }

    private func suspendedReconnect() async {
        await withCheckedContinuation { continuation in
            lock.withLock {
                reconnectResume = continuation
            }
        }
    }
}

@MainActor
private final class RecordingListener: Listener {
    private(set) var events: [PaEvent] = []

    func handle(_ event: PaEvent, reply: (@Sendable (PaEvent) -> Void)?) {
        events.append(event)
    }
}
