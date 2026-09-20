import Foundation

public final class XPCRemoteEventTransportClient: NSObject, RemoteEventTransportClient, @unchecked Sendable {
    private struct ReconnectStart {
        let generation: UInt64
        let connectionToInvalidate: NSXPCConnection?
        let stateHandler: (@Sendable (PaRemoteConnectionState) -> Void)?
    }

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
    private var state: PaRemoteConnectionState = .disconnected
    private var connectionGeneration: UInt64 = 0
    private var stopped = false

    public init(endpoint: NSXPCListenerEndpoint) {
        self.connectionSource = .endpoint(endpoint)
        super.init()
        establishConnectionLocked(generation: 0)
        Task { await self.completeHandshake(generation: 0) }
    }

    public init(machServiceName: String, options: NSXPCConnection.Options = []) {
        self.connectionSource = .mach(name: machServiceName, options: options)
        super.init()
        establishConnectionLocked(generation: 0)
        Task { await self.completeHandshake(generation: 0) }
    }

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
        guard let hostProxy = currentHostProxy(),
              let data = try? PaEventCodec.encode(event)
        else {
            return
        }

        hostProxy.publish(data)
    }

    public func subscribe(kinds: Set<PaEventKind>?) {
        guard let hostProxy = currentHostProxy() else { return }

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
        guard let reconnect = beginReconnect() else {
            throw PaEventRemoteError.notConnected
        }

        reconnect.stateHandler?(.connecting)

        invalidateConnection(reconnect.connectionToInvalidate)

        let established = lock.withLock {
            guard connectionGeneration == reconnect.generation,
                  !stopped,
                  state == .connecting
            else { return false }

            establishConnectionLocked(generation: reconnect.generation)
            return true
        }

        guard established else {
            setConnection(.disconnected, generation: reconnect.generation)
            throw PaEventRemoteError.notConnected
        }

        let connected = await completeHandshake(generation: reconnect.generation)

        guard connected else {
            setConnection(
                .disconnected,
                generation: reconnect.generation
            )
            throw PaEventRemoteError.notConnected
        }
    }

    private func beginReconnect() -> ReconnectStart? {
        lock.withLock {
            guard !stopped else { return nil }

            connectionGeneration &+= 1
            let generation = connectionGeneration

            let connectionToInvalidate = connection
            connection = nil
            hostProxy = nil
            state = .connecting

            return ReconnectStart(
                generation: generation,
                connectionToInvalidate: connectionToInvalidate,
                stateHandler: connectionStateHandler
            )
        }
    }

    public func close() {
        let connectionToInvalidate = lock.withLock { () -> NSXPCConnection? in

            guard !stopped else { return nil }

            stopped = true

            connectionGeneration &+= 1

            let connectionToInvalidate = connection
            connection = nil
            hostProxy = nil
            state = .disconnected

            deliveryHandler = nil
            connectionStateHandler = nil

            return connectionToInvalidate
        }

        invalidateConnection(connectionToInvalidate)
    }

    private func establishConnectionLocked(generation: UInt64) {
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
        connection.interruptionHandler = { [weak self] in
            self?.handleInterruption(generation: generation)
        }
        connection.invalidationHandler = { [weak self] in
            self?.handleInvalidation(generation: generation)
        }
        connection.resume()

        self.connection = connection
        self.hostProxy = connection.remoteObjectProxyWithErrorHandler { [weak self] _ in
            self?.handleInterruption(generation: generation)
        } as? PaEventHostXPC
        state = hostProxy == nil ? .disconnected : .connecting
    }

    private func invalidateConnection(
        _ connection: NSXPCConnection?
    ) {
        connection?.invalidationHandler = nil
        connection?.interruptionHandler = nil
        connection?.invalidate()
    }

    func handleInterruption(generation: UInt64) {
        setConnection(.disconnected, generation: generation)
    }

    func handleInvalidation(generation: UInt64) {
        lock.withLock {
            guard connectionGeneration == generation else { return }
            connection = nil
            hostProxy = nil
        }
        setConnection(.disconnected, generation: generation)
    }

    private func setConnection(_ newState: PaRemoteConnectionState, generation: UInt64) {
        let handler = lock.withLock { () -> (@Sendable (PaRemoteConnectionState) -> Void)? in
            guard connectionGeneration == generation else { return nil }
            state = newState
            return connectionStateHandler
        }
        handler?(newState)
    }

    private func completeHandshake(generation: UInt64) async -> Bool {
        let snapshot = lock.withLock { () -> (isCurrent: Bool, state: PaRemoteConnectionState) in
            (connectionGeneration == generation && !stopped, state)
        }

        guard snapshot.isCurrent else {
            return false
        }

        guard snapshot.state != .disconnected else {
            return false
        }

        guard await performHandshake(generation: generation) else {
            setConnection(.disconnected, generation: generation)
            return false
        }

        return commitConnected(generation: generation)
    }

    private func performHandshake(generation: UInt64) async -> Bool {
        guard let hostProxy = currentHostProxy() else { return false }

        return await withCheckedContinuation { continuation in
            let session = HandshakeSession(continuation: continuation)

            hostProxy.handshake { [weak self] isOk in
                guard let self else {
                    session.complete(false)
                    return
                }
                let isCurrent = self.lock.withLock {
                    self.connectionGeneration == generation && !self.stopped
                }
                session.complete(isCurrent && isOk)
            }

            Task {
                try? await Task.sleep(for: .seconds(2))
                session.complete(false)
            }
        }
    }

    func currentGeneration() -> UInt64 {
        lock.withLock { connectionGeneration }
    }

    private func currentHostProxy() -> PaEventHostXPC? {
        lock.withLock { hostProxy }
    }

    private func commitConnected(
        generation: UInt64
    ) -> Bool {
        let result = lock.withLock {
            () -> (
                committed: Bool,
                handler: (@Sendable (PaRemoteConnectionState) -> Void)?
            ) in

            guard connectionGeneration == generation,
                  !stopped,
                  state == .connecting,
                  connection != nil,
                  hostProxy != nil
            else {
                return (false, nil)
            }

            state = .connected

            return (true, connectionStateHandler)
        }

        if result.committed {
            result.handler?(.connected)
        }

        return result.committed
    }
}

private final class HandshakeSession: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Bool, Never>?

    init(continuation: CheckedContinuation<Bool, Never>) {
        self.continuation = continuation
    }

    func complete(_ value: Bool) {
        let continuation = lock.withLock { () -> CheckedContinuation<Bool, Never>? in
            defer { self.continuation = nil }
            return self.continuation
        }
        continuation?.resume(returning: value)
    }
}

extension XPCRemoteEventTransportClient: PaRemoteEventBusXPC {
    func deliver(_ data: Data) {
        guard let event = try? PaEventCodec.decode(data) else { return }
        let handler = lock.withLock { deliveryHandler }
        handler?(event)
    }
}
