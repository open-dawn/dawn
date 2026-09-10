import Foundation
import Observation
import PaEventKit

@Observable
@MainActor
final class PaSettingsEventBusService {
    private let transport: any RemoteEventTransportClient
    private let readyObserver: PaSettingsEventBusReadyObserver
    private var isRunning = false
    private var reconnectTask: Task<Void, Never>?

    private(set) var bus: PaRemoteEventBus
    private(set) var isConnected = false
    private(set) var connectionState: PaRemoteConnectionState = .disconnected

    init(
        transport: any RemoteEventTransportClient = XPCRemoteEventTransportClient(
            machServiceName: PaSettingsEventBusRendezvous.machServiceName
        ),
        readyObserver: PaSettingsEventBusReadyObserver = PaSettingsEventBusReadyObserver()
    ) {
        self.transport = transport
        self.readyObserver = readyObserver
        self.bus = PaRemoteEventBus(transport: transport)
        self.connectionState = transport.connectionState
        self.isConnected = transport.connectionState == .connected
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true

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
        scheduleReconnect()
    }

    func stop() {
        isRunning = false
        reconnectTask?.cancel()
        reconnectTask = nil
        readyObserver.stop()

        bus.setConnectionStateHandler(nil)
        bus.disconnect()
        connectionState = .disconnected
        isConnected = false
    }

    private func handleReadyPing() {
        scheduleReconnect()
    }

    private func handleConnectionStateChange(_ state: PaRemoteConnectionState) {
        let droppedWhileConnected = connectionState == .connected && state == .disconnected
        connectionState = state
        isConnected = state == .connected

        if droppedWhileConnected {
            scheduleReconnect()
        }
    }

    private func scheduleReconnect() {
        guard isRunning else { return }
        guard reconnectTask == nil else { return }

        reconnectTask = Task { @MainActor in
            defer { reconnectTask = nil }
            guard isRunning else { return }

            for _ in 0..<40 {
                guard isRunning else { return }
                switch bus.connectionState {
                case .connected:
                    handleConnectionStateChange(.connected)
                    return
                case .connecting:
                    try? await Task.sleep(for: .milliseconds(50))
                case .disconnected:
                    break
                }
                if bus.connectionState != .connecting {
                    break
                }
            }

            guard isRunning, bus.connectionState != .connected else { return }

            do {
                try await bus.attemptReconnect()
            } catch {
                connectionState = .disconnected
                isConnected = false
            }
        }
    }
}
