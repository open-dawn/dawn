import Foundation

public final class LoopbackRemoteEventTransportClient: RemoteEventTransportClient, @unchecked Sendable {
    private let lock = NSLock()
    private var deliveryHandler: (@Sendable (PaEvent) -> Void)?
    private var connectionStateHandler: (@Sendable (PaRemoteConnectionState) -> Void)?
    private var state: PaRemoteConnectionState = .connected
    private var stopped = false
    weak var server: LoopbackRemoteEventTransportServer?

    public var isConnected: Bool {
        lock.withLock { state == .connected }
    }

    public var connectionState: PaRemoteConnectionState {
        lock.withLock { state }
    }

    public func setDeliveryHandler(_ handler: @escaping @Sendable (PaEvent) -> Void) {
        lock.withLock {
            deliveryHandler = handler
        }
    }

    public func setConnectionStateHandler(
        _ handler: (@Sendable (PaRemoteConnectionState) -> Void)?
    ) {
        lock.withLock {
            connectionStateHandler = handler
        }
    }

    public func publish(_ event: PaEvent) {
        server?.handlePublish(event)
    }

    public func subscribe(kinds: Set<PaEventKind>?) {
        server?.handleSubscribe(kinds)
    }

    public func ask(_ event: PaEvent) async throws -> PaEvent {
        guard isConnected, let server else {
            throw PaEventRemoteError.notConnected
        }
        return try await server.handleAsk(event)
    }

    public func attemptReconnect() async throws {
        let canReconnect = lock.withLock { () -> Bool in
            guard !stopped, server != nil else { return false }
            state = .connecting
            return true
        }

        guard canReconnect else {
            setConnectionState(.disconnected)
            throw PaEventRemoteError.notConnected
        }

        setConnectionState(.connected)
    }

    public func close() {
        let shouldClose = lock.withLock { () -> Bool in
            guard !stopped else { return false }
            stopped = true
            state = .disconnected
            deliveryHandler = nil
            connectionStateHandler = nil
            return true
        }

        guard shouldClose else { return }
        server?.handleClose()
        notifyConnectionState(.disconnected)
    }

    func receiveDeliver(_ event: PaEvent) {
        let handler = lock.withLock { deliveryHandler }
        handler?(event)
    }

    func simulateDisconnect() {
        let shouldNotify = lock.withLock { () -> Bool in
            guard !stopped, state == .connected else { return false }
            state = .disconnected
            return true
        }

        guard shouldNotify else { return }
        notifyConnectionState(.disconnected)
    }

    func simulateConnecting() {
        setConnectionState(.connecting)
    }

    private func setConnectionState(_ newState: PaRemoteConnectionState) {
        lock.withLock {
            state = newState
        }
        notifyConnectionState(newState)
    }

    private func notifyConnectionState(_ state: PaRemoteConnectionState) {
        let handler = lock.withLock { connectionStateHandler }
        handler?(state)
    }
}
