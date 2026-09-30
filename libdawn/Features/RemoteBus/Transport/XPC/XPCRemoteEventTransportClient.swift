// swiftlint:disable file_length

import Foundation
import dawnLogging

// swiftlint:disable:next type_body_length
public final class XPCRemoteEventTransportClient: NSObject, RemoteEventTransportClient, @unchecked Sendable {
    private struct ReconnectStart {
        let generation: UInt64
        let connectionToInvalidate: NSXPCConnection?
        let stateHandler: (@Sendable (RemoteConnectionState) -> Void)?
    }

    private enum ConnectionSource: Sendable {
        case mach(name: String, options: NSXPCConnection.Options)
        case endpoint(NSXPCListenerEndpoint)
    }

    private let lock = NSLock()
    private let connectionSource: ConnectionSource
    private var connection: NSXPCConnection?
    private var hostProxy: EventHostXPC?
    private var deliveryHandler: (@Sendable (Event) -> Void)?
    private var connectionStateHandler: (@Sendable (RemoteConnectionState) -> Void)?
    private var state: RemoteConnectionState = .disconnected
    private var connectionGeneration: UInt64 = 0
    private var stopped = false

    public init(endpoint: NSXPCListenerEndpoint) {
        self.connectionSource = .endpoint(endpoint)
        super.init()
        #log(
            "Initializing XPC transport client with listener endpoint; generation: 0",
            level: .info,
            category: .transport
        )
        establishConnectionLocked(generation: 0)
        Task { await self.completeHandshake(generation: 0) }
    }

    public init(machServiceName: String, options: NSXPCConnection.Options = []) {
        self.connectionSource = .mach(name: machServiceName, options: options)
        super.init()
        #log(
            "Initializing XPC transport client for Mach service \(machServiceName, privacy: .public); generation: 0",
            level: .info,
            category: .transport
        )
        establishConnectionLocked(generation: 0)
        Task { await self.completeHandshake(generation: 0) }
    }

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
        #log("Installed delivery handler", category: .transport)
    }

    public func setConnectionStateHandler(
        _ handler: (@Sendable (RemoteConnectionState) -> Void)?
    ) {
        lock.withLock {
            connectionStateHandler = handler
        }
    }

    public func publish(_ event: Event) {
        guard let hostProxy = currentHostProxy(),
              let data = try? EventCodec.encode(event)
        else {
            return
        }

        hostProxy.publish(data)
    }

    public func subscribe(kinds: Set<EventKind>?) {
        guard let hostProxy = currentHostProxy() else { return }

        if let kinds {
            hostProxy.subscribe(kinds.map(\.rawValue), includeAll: false)
        } else {
            hostProxy.subscribe([], includeAll: true)
        }
    }

    public func ask(_ event: Event) async throws -> Event {
        guard let hostProxy = currentHostProxy() else {
            #log(
                "Rejecting ask because no host proxy is available",
                level: .warning,
                category: .transport
            )
            throw EventRemoteError.notConnected
        }

        let data = try EventCodec.encode(event)

        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            let resumeLock = NSLock()

            hostProxy.ask(data) { responseData, error in
                resumeLock.withLock {
                    guard !resumed else { return }
                    resumed = true

                    if let error {
                        #log(
                            "Ask failed: \(error.localizedDescription, privacy: .public)",
                            level: .error,
                            category: .transport
                        )
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let responseData else {
                        #log(
                            "Ask returned neither response data nor an error",
                            level: .error,
                            category: .transport
                        )
                        continuation.resume(throwing: EventRemoteError.invalidPayload)
                        return
                    }

                    do {
                        continuation.resume(returning: try EventCodec.decode(responseData))
                    } catch {
                        #log(
                            "Failed to decode ask response: \(error.localizedDescription, privacy: .public)",
                            level: .error,
                            category: .transport
                        )
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    public func attemptReconnect() async throws {
        guard let reconnect = beginReconnect() else {
            #log(
                "Reconnect rejected because transport is stopped",
                level: .warning,
                category: .transport
            )
            throw EventRemoteError.notConnected
        }

        #log(
            "Reconnect starting; generation: \(reconnect.generation, privacy: .public)",
            level: .info,
            category: .transport
        )
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
            #log(
                "Reconnect superseded before connection setup; generation: \(reconnect.generation, privacy: .public)",
                level: .warning,
                category: .transport
            )
            setConnection(.disconnected, generation: reconnect.generation)
            throw EventRemoteError.notConnected
        }

        let connected = await completeHandshake(generation: reconnect.generation)

        guard connected else {
            #log(
                "Reconnect handshake failed; generation: \(reconnect.generation, privacy: .public)",
                level: .error,
                category: .transport
            )
            setConnection(
                .disconnected,
                generation: reconnect.generation
            )
            throw EventRemoteError.notConnected
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
            #log(
                """
                Creating XPC connection to Mach service \(name, privacy: .public); \
                generation: \(generation, privacy: .public)
                """,
                level: .info,
                category: .transport
            )
            connection = NSXPCConnection(machServiceName: name, options: options)
        case let .endpoint(endpoint):
            #log(
                "Creating XPC connection from listener endpoint; generation: \(generation, privacy: .public)",
                level: .info,
                category: .transport
            )
            connection = NSXPCConnection(listenerEndpoint: endpoint)
        }

        connection.exportedInterface = NSXPCInterface(with: RemoteEventBusXPC.self)
        connection.exportedObject = self
        connection.remoteObjectInterface = NSXPCInterface(with: EventHostXPC.self)
        connection.interruptionHandler = { [weak self] in
            self?.handleInterruption(generation: generation)
        }
        connection.invalidationHandler = { [weak self] in
            self?.handleInvalidation(generation: generation)
        }
        connection.resume()
        #log(
            "Resumed XPC connection; generation: \(generation, privacy: .public)",
            category: .transport
        )

        self.connection = connection
        self.hostProxy = connection.remoteObjectProxyWithErrorHandler { [weak self] error in
            #log(
                """
                XPC remote proxy error; generation: \(generation, privacy: .public), \
                error: \(error.localizedDescription, privacy: .public)
                """,
                level: .error,
                category: .transport
            )
            self?.handleInterruption(generation: generation)
        } as? EventHostXPC
        state = hostProxy == nil ? .disconnected : .connecting
    }

    private func invalidateConnection(
        _ connection: NSXPCConnection?
    ) {
        #log("Invalidating existing XPC connection", category: .transport)
        connection?.invalidationHandler = nil
        connection?.interruptionHandler = nil
        connection?.invalidate()
    }

    func handleInterruption(generation: UInt64) {
        #log(
            "XPC connection interrupted; generation: \(generation, privacy: .public)",
            level: .warning,
            category: .transport
        )
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

    private func setConnection(_ newState: RemoteConnectionState, generation: UInt64) {
        let handler = lock.withLock { () -> (@Sendable (RemoteConnectionState) -> Void)? in
            guard connectionGeneration == generation else { return nil }
            state = newState
            return connectionStateHandler
        }
        handler?(newState)
    }

    func currentGeneration() -> UInt64 {
        lock.withLock { connectionGeneration }
    }

    private func currentHostProxy() -> EventHostXPC? {
        lock.withLock { hostProxy }
    }
}

private extension XPCRemoteEventTransportClient {
    private func completeHandshake(generation: UInt64) async -> Bool {
        let snapshot = lock.withLock { () -> (isCurrent: Bool, state: RemoteConnectionState) in
            (connectionGeneration == generation && !stopped, state)
        }

        guard snapshot.isCurrent else {
            return false
        }

        guard snapshot.state != .disconnected else {
            return false
        }

        #log(
            "Starting XPC handshake; generation: \(generation, privacy: .public)",
            level: .info,
            category: .transport
        )
        guard await performHandshake(generation: generation) else {
            #log(
                "XPC handshake did not succeed; generation: \(generation, privacy: .public)",
                level: .error,
                category: .transport
            )
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

    private func commitConnected(
        generation: UInt64
    ) -> Bool {
        let result = lock.withLock {
            () -> (
                committed: Bool,
                handler: (@Sendable (RemoteConnectionState) -> Void)?
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

extension XPCRemoteEventTransportClient: RemoteEventBusXPC {
    func deliver(_ data: Data) {
        guard let event = try? EventCodec.decode(data) else { return }
        let handler = lock.withLock { deliveryHandler }
        handler?(event)
    }
}
