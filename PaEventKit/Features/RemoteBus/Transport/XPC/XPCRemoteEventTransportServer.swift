import Foundation

final class XPCRemoteEventTransportServer: NSObject, RemoteEventTransportServer, PaEventHostXPC, @unchecked Sendable {
    private let connection: NSXPCConnection
    private let lock = NSLock()
    private var closed = false
    private var publishHandler: (@Sendable (PaEvent) -> Void)?
    private var subscribeHandler: (@Sendable (Set<PaEventKind>?) -> Void)?
    private var askHandler: (@Sendable (PaEvent) async throws -> PaEvent)?
    private var closeHandler: (@Sendable () -> Void)?

    init(connection: NSXPCConnection) {
        self.connection = connection
        super.init()
    }

    func deliver(_ event: PaEvent) {
        guard let data = try? PaEventCodec.encode(event) else { return }
        let proxy = connection.remoteObjectProxy as? PaRemoteEventBusXPC
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

    func setPublishHandler(_ handler: (@Sendable (PaEvent) -> Void)?) {
        lock.withLock {
            publishHandler = handler
        }
    }

    func setSubscribeHandler(_ handler: (@Sendable (Set<PaEventKind>?) -> Void)?) {
        lock.withLock {
            subscribeHandler = handler
        }
    }

    func setAskHandler(_ handler: (@Sendable (PaEvent) async throws -> PaEvent)?) {
        lock.withLock {
            askHandler = handler
        }
    }

    func setCloseHandler(_ handler: (@Sendable () -> Void)?) {
        lock.withLock {
            closeHandler = handler
        }
    }

    func publish(_ data: Data) {
        guard let event = try? PaEventCodec.decode(data) else { return }

        let handler = lock.withLock { publishHandler }

        handler?(event)
    }

    func subscribe(_ kindNames: [String], includeAll: Bool) {
        let handler = lock.withLock { subscribeHandler }

        if includeAll {
            handler?(nil)
            return
        }

        handler?(Set(kindNames.compactMap { PaEventKind(rawValue: $0) }))
    }

    func ask(_ data: Data, withReply reply: @escaping (Data?, Error?) -> Void) {
        let handler = lock.withLock { askHandler }

        nonisolated(unsafe) let reply = reply
        Task {
            do {
                let event = try PaEventCodec.decode(data)
                guard let handler else {
                    reply(nil, PaEventRemoteError.notConnected)
                    return
                }
                let response = try await handler(event)
                reply(try PaEventCodec.encode(response), nil)
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
