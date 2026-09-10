import Foundation

public final class XPCRemoteEventTransportClient: NSObject, RemoteEventTransportClient, @unchecked Sendable {
    private enum ConnectionSource: Sendable {
        case mach(name: String, options: NSXPCConnection.Options)
        case endpoint(NSXPCListenerEndpoint)
    }

    private let lock = NSLock()
    private let connectionSource: ConnectionSource
    private var connection: NSXPCConnection?
    private var hostProxy: PaEventHostXPC?
    private var deliveryHandler: (@Sendable (PaEvent) -> Void)?
    private var connectionStateHandler: (@Sendable (PaRemoteConnectionState) -> Void)?
    private var stopped = false

    public init(endpoint: NSXPCListenerEndpoint) {
        self.connectionSource = .endpoint(endpoint)
        super.init()
        establishConnectionLocked()
    }

    public init(machServiceName: String, options: NSXPCConnection.Options = []) {
        self.connectionSource = .mach(name: machServiceName, options: options)
        super.init()
        establishConnectionLocked()
    }

    public var isConnected: Bool {
        lock.withLock { connection != nil }
    }

    public var connectionState: PaRemoteConnectionState {
        lock.withLock { connection != nil ? .connected : .disconnected }
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

    public func attemptReconnect() async throws {
        let canReconnect = lock.withLock { !stopped }
        guard canReconnect else {
            notifyConnectionState(.disconnected)
            throw PaEventRemoteError.notConnected
        }

        let connectionToInvalidate = lock.withLock { () -> NSXPCConnection? in
            let connection = self.connection
            tearDownConnectionLocked(clearHandlers: false)
            return connection
        }
        connectionToInvalidate?.invalidate()

        let established = lock.withLock { () -> Bool in
            guard !stopped else { return false }
            establishConnectionLocked()
            return connection != nil
        }

        guard established else {
            notifyConnectionState(.disconnected)
            throw PaEventRemoteError.notConnected
        }

        notifyConnectionState(.connected)
    }

    public func close() {
        let connection = lock.withLock { () -> NSXPCConnection? in
            stopped = true
            let connection = self.connection
            tearDownConnectionLocked(clearHandlers: true)
            return connection
        }
        connection?.invalidate()
        notifyConnectionState(.disconnected)
    }

    private func establishConnectionLocked() {
        let connection: NSXPCConnection
        switch connectionSource {
        case let .mach(name, options):
            connection = NSXPCConnection(machServiceName: name, options: options)
        case let .endpoint(endpoint):
            connection = NSXPCConnection(listenerEndpoint: endpoint)
        }

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

    private func tearDownConnectionLocked(clearHandlers: Bool) {
        connection?.invalidationHandler = nil
        connection = nil
        hostProxy = nil

        if clearHandlers {
            deliveryHandler = nil
            connectionStateHandler = nil
        }
    }

    private func handleInvalidation() {
        lock.withLock {
            connection = nil
            hostProxy = nil
        }
        notifyConnectionState(.disconnected)
    }

    private func notifyConnectionState(_ state: PaRemoteConnectionState) {
        let handler = lock.withLock { connectionStateHandler }
        handler?(state)
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
