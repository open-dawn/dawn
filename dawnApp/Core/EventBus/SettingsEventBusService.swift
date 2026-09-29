import Foundation
import Observation
import libdawn
import dawnLogging

@Observable
@MainActor
final class SettingsEventBusService {
    private let transport: any RemoteEventTransportClient
    private let readyObserver: SettingsEventBusReadyObserver
    private var isRunning = false
    private var reconnectTask: Task<Void, Never>?
    private var retryAfterInitialHandshake = false
    private var reconnectRequested = false

    private(set) var bus: RemoteEventBus
    private(set) var isConnected = false
    private(set) var connectionState: RemoteConnectionState = .disconnected

    init(
        transport: any RemoteEventTransportClient = XPCRemoteEventTransportClient(
            machServiceName: SettingsEventBusRendezvous.machServiceName
        ),
        readyObserver: SettingsEventBusReadyObserver = SettingsEventBusReadyObserver()
    ) {
        self.transport = transport
        self.readyObserver = readyObserver
        self.bus = RemoteEventBus(transport: transport)
        self.connectionState = transport.connectionState
        self.isConnected = transport.connectionState == .connected
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

        let droppedWhileConnected = connectionState == .connected && state == .disconnected

        let initialHandshakeFailed =
            retryAfterInitialHandshake
            && connectionState == .connecting
            && state == .disconnected

        connectionState = state
        isConnected = state == .connected

        if state == .connected {
            retryAfterInitialHandshake = false
        }

        if droppedWhileConnected || initialHandshakeFailed {
            retryAfterInitialHandshake = false
            reconnectIfNeeded()
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
