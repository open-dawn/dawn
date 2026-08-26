import Foundation

public final class LoopbackRemoteEventTransportClient: RemoteEventTransportClient, @unchecked Sendable {
    private let lock = NSLock()
    private var deliveryHandler: (@Sendable (PaEvent) -> Void)?
    private var connected = true
    weak var server: LoopbackRemoteEventTransportServer?

    public var isConnected: Bool {
        lock.withLock { connected }
    }

    public func setDeliveryHandler(_ handler: @escaping @Sendable (PaEvent) -> Void) {
        lock.withLock {
            deliveryHandler = handler
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

    public func close() {
        let shouldClose = lock.withLock {
            guard connected else { return false }
            connected = false
            deliveryHandler = nil
            return true
        }

        guard shouldClose else { return }
        server?.handleClose()
    }

    func receiveDeliver(_ event: PaEvent) {
        let handler = lock.withLock { deliveryHandler }
        handler?(event)
    }
}
