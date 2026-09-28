import Foundation

public final class LoopbackRemoteEventTransportClient: RemoteEventTransportClient, @unchecked Sendable {
    private let lock = NSLock()
    private var deliveryHandler: (@Sendable (Event) -> Void)?
    private var connectionStateHandler: (@Sendable (RemoteConnectionState) -> Void)?
    private var state: RemoteConnectionState = .connected
    private var stopped = false
    weak var server: LoopbackRemoteEventTransportServer?

    public var isConnected: Bool {
        lock.withLock { state == .connected }
    }

    public var connectionState: RemoteConnectionState {
        lock.withLock { state }
    }

    public func setDeliveryHandler(_ handler: @escaping @Sendable (Event) -> Void) {
        lock.withLock {
            deliveryHandler = handler
        }
    }

    public func setConnectionStateHandler(
        _ handler: (@Sendable (RemoteConnectionState) -> Void)?
    ) {
        lock.withLock {
            connectionStateHandler = handler
        }
    }

    public func publish(_ event: Event) {
        server?.handlePublish(event)
    }

    public func subscribe(kinds: Set<EventKind>?) {
        server?.handleSubscribe(kinds)
    }

    public func ask(_ event: Event) async throws -> Event {
        guard isConnected, let server else {
            throw EventRemoteError.notConnected
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
            throw EventRemoteError.notConnected
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

    func receiveDeliver(_ event: Event) {
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

    private func setConnectionState(_ newState: RemoteConnectionState) {
        lock.withLock {
            state = newState
        }
        notifyConnectionState(newState)
    }

    private func notifyConnectionState(_ state: RemoteConnectionState) {
        let handler = lock.withLock { connectionStateHandler }
        handler?(state)
    }
}
