import Foundation

public final class LoopbackRemoteEventTransportClient: RemoteEventTransportClient, @unchecked Sendable {
    private let lock = NSLock()
    private var deliveryHandler: (@Sendable (PaEvent) -> Void)?
    private var connected = true
    weak var server: LoopbackRemoteEventTransportServer?

    public var isConnected: Bool {
        lock.lock()
        defer { lock.unlock() }
        return connected
    }

    public func setDeliveryHandler(_ handler: @escaping @Sendable (PaEvent) -> Void) {
        lock.lock()
        deliveryHandler = handler
        lock.unlock()
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
        lock.lock()
        guard connected else {
            lock.unlock()
            return
        }
        connected = false
        deliveryHandler = nil
        lock.unlock()

        server?.handleClose()
    }

    func receiveDeliver(_ event: PaEvent) {
        lock.lock()
        let handler = deliveryHandler
        lock.unlock()
        handler?(event)
    }
}
