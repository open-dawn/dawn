import Foundation

public final class XPCRemoteEventTransportClient: NSObject, RemoteEventTransportClient, @unchecked Sendable {
    private let lock = NSLock()
    private var connection: NSXPCConnection?
    private var hostProxy: PaEventHostXPC?
    private var deliveryHandler: (@Sendable (PaEvent) -> Void)?

    public init(endpoint: NSXPCListenerEndpoint) {
        super.init()
        configure(connection: NSXPCConnection(listenerEndpoint: endpoint))
    }

    public init(machServiceName: String, options: NSXPCConnection.Options = []) {
        super.init()
        configure(connection: NSXPCConnection(machServiceName: machServiceName, options: options))
    }

    private func configure(connection: NSXPCConnection) {
        connection.exportedInterface = NSXPCInterface(with: PaRemoteEventBusXPC.self)
        connection.exportedObject = self
        connection.remoteObjectInterface = NSXPCInterface(with: PaEventHostXPC.self)
        connection.invalidationHandler = { [weak self] in
            self?.handleInvalidation()
        }
        connection.resume()

        self.connection = connection
        self.hostProxy = connection.remoteObjectProxyWithErrorHandler { _ in
        } as? PaEventHostXPC
    }

    public var isConnected: Bool {
        lock.withLock { connection != nil }
    }

    public func setDeliveryHandler(_ handler: @escaping @Sendable (PaEvent) -> Void) {
        lock.withLock {
            deliveryHandler = handler
        }
    }

    public func publish(_ event: PaEvent) {
        guard let hostProxy, let data = try? PaEventCodec.encode(event) else { return }
        hostProxy.publish(data)
    }

    public func subscribe(kinds: Set<PaEventKind>?) {
        guard let hostProxy else { return }

        if let kinds {
            hostProxy.subscribe(kinds.map(\.rawValue), includeAll: false)
        } else {
            hostProxy.subscribe([], includeAll: true)
        }
    }

    public func ask(_ event: PaEvent) async throws -> PaEvent {
        guard let hostProxy = currentHostProxy() else {
            throw PaEventRemoteError.notConnected
        }

        let data = try PaEventCodec.encode(event)

        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            let resumeLock = NSLock()

            hostProxy.ask(data) { responseData, error in
                resumeLock.withLock {
                    guard !resumed else { return }
                    resumed = true

                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let responseData else {
                        continuation.resume(throwing: PaEventRemoteError.invalidPayload)
                        return
                    }

                    do {
                        continuation.resume(returning: try PaEventCodec.decode(responseData))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    public func close() {
        let connection = lock.withLock {
            let connection = self.connection
            self.connection = nil
            self.hostProxy = nil
            return connection
        }
        connection?.invalidate()
    }

    private func handleInvalidation() {
        lock.withLock {
            connection = nil
            hostProxy = nil
        }
    }

    private func currentHostProxy() -> PaEventHostXPC? {
        lock.withLock { hostProxy }
    }
}

extension XPCRemoteEventTransportClient: PaRemoteEventBusXPC {
    func deliver(_ data: Data) {
        guard let event = try? PaEventCodec.decode(data) else { return }
        let handler = lock.withLock { deliveryHandler }
        handler?(event)
    }
}
