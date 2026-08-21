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
        lock.lock()
        let shouldInvalidate = !closed
        closed = true
        lock.unlock()

        guard shouldInvalidate else { return }
        connection.invalidate()
    }

    func setPublishHandler(_ handler: (@Sendable (PaEvent) -> Void)?) {
        lock.lock()
        publishHandler = handler
        lock.unlock()
    }

    func setSubscribeHandler(_ handler: (@Sendable (Set<PaEventKind>?) -> Void)?) {
        lock.lock()
        subscribeHandler = handler
        lock.unlock()
    }

    func setAskHandler(_ handler: (@Sendable (PaEvent) async throws -> PaEvent)?) {
        lock.lock()
        askHandler = handler
        lock.unlock()
    }

    func setCloseHandler(_ handler: (@Sendable () -> Void)?) {
        lock.lock()
        closeHandler = handler
        lock.unlock()
    }

    func publish(_ data: Data) {
        guard let event = try? PaEventCodec.decode(data) else { return }
        lock.lock()
        let handler = publishHandler
        lock.unlock()
        handler?(event)
    }

    func subscribe(_ kindNames: [String], includeAll: Bool) {
        lock.lock()
        let handler = subscribeHandler
        lock.unlock()

        if includeAll {
            handler?(nil)
            return
        }

        handler?(Set(kindNames.compactMap { PaEventKind(rawValue: $0) }))
    }

    func ask(_ data: Data, withReply reply: @escaping (Data?, Error?) -> Void) {
        lock.lock()
        let handler = askHandler
        lock.unlock()

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
        lock.lock()
        let handler = closeHandler
        lock.unlock()
        handler?()
    }
}
