import Foundation

final class XPCRemoteEventTransportServer: NSObject, RemoteEventTransportServer, EventHostXPC, @unchecked Sendable {
    private let connection: NSXPCConnection
    private let lock = NSLock()
    private var closed = false
    private var publishHandler: (@Sendable (Event) -> Void)?
    private var subscribeHandler: (@Sendable (Set<EventKind>?) -> Void)?
    private var askHandler: (@Sendable (Event) async throws -> Event)?
    private var closeHandler: (@Sendable () -> Void)?

    init(connection: NSXPCConnection) {
        self.connection = connection
        super.init()
    }

    func deliver(_ event: Event) {
        guard let data = try? EventCodec.encode(event) else { return }
        let proxy = connection.remoteObjectProxy as? RemoteEventBusXPC
        proxy?.deliver(data)
    }

    func close() {
        let shouldInvalidate = lock.withLock {
            let shouldInvalidate = !closed
            closed = true
            return shouldInvalidate
        }

        guard shouldInvalidate else { return }

        connection.invalidate()
    }

    func setPublishHandler(_ handler: (@Sendable (Event) -> Void)?) {
        lock.withLock {
            publishHandler = handler
        }
    }

    func setSubscribeHandler(_ handler: (@Sendable (Set<EventKind>?) -> Void)?) {
        lock.withLock {
            subscribeHandler = handler
        }
    }

    func setAskHandler(_ handler: (@Sendable (Event) async throws -> Event)?) {
        lock.withLock {
            askHandler = handler
        }
    }

    func setCloseHandler(_ handler: (@Sendable () -> Void)?) {
        lock.withLock {
            closeHandler = handler
        }
    }

    func handshake(withReply reply: @escaping (Bool) -> Void) {
        reply(true)
    }

    func publish(_ data: Data) {
        guard let event = try? EventCodec.decode(data) else { return }

        let handler = lock.withLock { publishHandler }

        handler?(event)
    }

    func subscribe(_ kindNames: [String], includeAll: Bool) {
        let handler = lock.withLock { subscribeHandler }

        if includeAll {
            handler?(nil)
            return
        }

        handler?(Set(kindNames.compactMap { EventKind(rawValue: $0) }))
    }

    func ask(_ data: Data, withReply reply: @escaping (Data?, Error?) -> Void) {
        let handler = lock.withLock { askHandler }

        nonisolated(unsafe) let reply = reply
        Task {
            do {
                let event = try EventCodec.decode(data)
                guard let handler else {
                    reply(nil, EventRemoteError.notConnected)
                    return
                }
                let response = try await handler(event)
                reply(try EventCodec.encode(response), nil)
            } catch {
                reply(nil, error)
            }
        }
    }

    func handleInvalidation() {
        let handler = lock.withLock { closeHandler }
        handler?()
    }
}
