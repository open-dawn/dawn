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
    private(set) var reconnectAttempts = 0

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
        client.setConnectionStateHandler(handler)
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
        reconnectAttempts += 1
        guard allowReconnect else {
            throw PaEventRemoteError.notConnected
        }

        client.simulateConnecting()

        if pauseInConnecting {
            await withCheckedContinuation { continuation in
                lock.withLock {
                    reconnectResume = continuation
                }
            }
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
}

@MainActor
private final class RecordingListener: Listener {
    private(set) var events: [PaEvent] = []

    func handle(_ event: PaEvent, reply: (@Sendable (PaEvent) -> Void)?) {
        events.append(event)
    }
}
