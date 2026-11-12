import Foundation
import Observation
import libdawn
import dawnLogging

enum SettingsEventBusConnectionError: Error, Equatable {
    case timeout
}

@Observable
@MainActor
final class SettingsEventBusService: AgentUpdateConnectionWaiting {
    private let transport: any RemoteEventTransportClient
    private let readyObserver: SettingsEventBusReadyObserver
    private var isRunning = false
    private var reconnectTask: Task<Void, Never>?
    private var retryAfterInitialHandshake = false
    private var reconnectRequested = false

    private(set) var bus: RemoteEventBus
    private(set) var isConnected = false
    private(set) var connectionState: RemoteConnectionState = .disconnected
    private(set) var connectionGeneration: UInt

    init(
        transport: (any RemoteEventTransportClient)? = nil,
        readyObserver: SettingsEventBusReadyObserver = SettingsEventBusReadyObserver()
    ) {
        let transport = transport ?? Self.makeTransport()
        self.transport = transport
        self.readyObserver = readyObserver
        self.bus = RemoteEventBus(transport: transport)

        let initialState = transport.connectionState

        connectionState = initialState
        isConnected = initialState == .connected
        connectionGeneration = initialState == .connected ? 1 : 0
    }

    private static func makeTransport() -> any RemoteEventTransportClient {
        #if DEBUG
        DistributedRemoteEventTransportClient(
            serviceName: EventBusMachService.developmentServiceName
        )
        #else
        XPCRemoteEventTransportClient(
            machServiceName: SettingsEventBusRendezvous.machServiceName
        )
        #endif
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        retryAfterInitialHandshake = true

        let state = String(describing: bus.connectionState)

        #log(
            "Starting SettingUI event bus; initial state: \(state, privacy: .public)",
            level: .info,
            category: .eventBus
        )

        bus.setConnectionStateHandler { [weak self] state in
            Task { @MainActor in
                self?.handleConnectionStateChange(state)
            }
        }

        readyObserver.start { [weak self] in
            Task { @MainActor in
                self?.handleReadyPing()
            }
        }

        handleConnectionStateChange(bus.connectionState)
        reconnectIfNeeded()
    }

    func stop() {
        isRunning = false
        reconnectRequested = false
        retryAfterInitialHandshake = false
        reconnectTask?.cancel()
        reconnectTask = nil
        readyObserver.stop()

        bus.setConnectionStateHandler(nil)
        bus.disconnect()
        connectionState = .disconnected
        isConnected = false
    }

    private func handleReadyPing() {
        #log(
            "Received dawnAgent ready notification",
            level: .info,
            category: .eventBus
        )

        reconnectIfNeeded()
    }

    private func handleConnectionStateChange(_ state: RemoteConnectionState) {
        guard isRunning else { return }

        let wasConnected = connectionState == .connected

        let droppedWhileConnected = connectionState == .connected && state == .disconnected

        let initialHandshakeFailed =
            retryAfterInitialHandshake
            && connectionState == .connecting
            && state == .disconnected

        connectionState = state
        isConnected = state == .connected

        if state == .connected {
            if !wasConnected {
                connectionGeneration &+= 1
            }

            retryAfterInitialHandshake = false
        }

        if droppedWhileConnected || initialHandshakeFailed {
            retryAfterInitialHandshake = false
            reconnectIfNeeded()
        }
    }

    func waitUntilConnected(after generation: UInt?, timeout: Duration) async throws {
        let deadline = ContinuousClock.now + timeout

        while true {
            try Task.checkCancellation()

            let reachedRequiredGeneration = generation.map { connectionGeneration != $0 } ?? true

            if isConnected && reachedRequiredGeneration {
                return
            }

            guard ContinuousClock.now < deadline else {
                throw SettingsEventBusConnectionError.timeout
            }

            try await Task.sleep(for: .milliseconds(25))
        }
    }

    private func reconnectIfNeeded() {
        guard isRunning else { return }
        guard reconnectTask == nil else {
            reconnectRequested = true
            return
        }

        switch bus.connectionState {
        case .connected, .connecting:
            return
        case .disconnected:
            break
        }

        reconnectTask = Task { @MainActor in
            defer { reconnectAttemptFinished() }

            guard isRunning, bus.connectionState == .disconnected else { return }

            do {
                try await bus.attemptReconnect()
            } catch {
                connectionState = .disconnected
                isConnected = false
            }
        }
    }

    private func reconnectAttemptFinished() {
        reconnectTask = nil

        guard isRunning else {
            reconnectRequested = false
            return
        }

        guard reconnectRequested else {
            return
        }

        reconnectRequested = false
        reconnectIfNeeded()
    }
}
