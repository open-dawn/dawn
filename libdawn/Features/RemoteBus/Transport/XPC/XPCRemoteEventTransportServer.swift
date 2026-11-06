import Foundation
import dawnLogging

// swiftlint:disable:next type_body_length
final class XPCRemoteEventTransportServer: NSObject, RemoteEventTransportServer, EventHostXPC, @unchecked Sendable {
    private let connection: NSXPCConnection
    private let identifier = UUID().uuidString
    private let lock = NSLock()
    private var closed = false
    private var publishHandler: (@Sendable (Event) -> Void)?
    private var subscribeHandler: (@Sendable (Set<EventKind>?) -> Void)?
    private var askHandler: (@Sendable (Event) async throws -> Event)?
    private var closeHandler: (@Sendable () -> Void)?

    init(connection: NSXPCConnection) {
        self.connection = connection
        super.init()
        #log(
            """
            Created XPC transport server; connection ID: \(self.identifier, privacy: .public), \
            remote process: \(connection.processIdentifier, privacy: .public)
            """,
            level: .info,
            category: .transport
        )
    }

    func deliver(_ event: Event) {
        let data: Data
        do {
            data = try EventCodec.encode(event)
        } catch {
            #log(
                """
                Failed to encode event for delivery; connection ID: \(self.identifier, privacy: .public), \
                error: \(error.localizedDescription, privacy: .public)
                """,
                level: .error,
                category: .transport
            )
            return
        }

        let identifier = self.identifier
        let proxy =
            connection.remoteObjectProxyWithErrorHandler { error in
                #log(
                    """
                    XPC client proxy error while delivering event; \
                    connection ID: \(identifier, privacy: .public), \
                    error: \(error.localizedDescription, privacy: .public)
                    """,
                    level: .error,
                    category: .transport
                )
            } as? RemoteEventBusXPC

        guard let proxy else {
            #log(
                "Could not create XPC client proxy for delivery; connection ID: \(identifier, privacy: .public)",
                level: .error,
                category: .transport
            )
            return
        }

        proxy.deliver(data)
    }

    func close() {
        let shouldInvalidate = lock.withLock {
            let shouldInvalidate = !closed
            closed = true
            return shouldInvalidate
        }

        guard shouldInvalidate else {
            #log(
                """
                Ignoring close because XPC transport server is already closed; \
                connection ID: \(self.identifier, privacy: .public)
                """,
                category: .transport
            )
            return
        }

        #log(
            "Closing XPC transport server; connection ID: \(self.identifier, privacy: .public)",
            level: .info,
            category: .transport
        )
        connection.invalidate()
    }

    func setPublishHandler(_ handler: (@Sendable (Event) -> Void)?) {
        lock.withLock {
            publishHandler = handler
        }
        let action = handler == nil ? "Cleared" : "Installed"
        #log(
            "\(action, privacy: .public) publish handler; connection ID: \(self.identifier, privacy: .public)",
            category: .transport
        )
    }

    func setSubscribeHandler(_ handler: (@Sendable (Set<EventKind>?) -> Void)?) {
        lock.withLock {
            subscribeHandler = handler
        }
        let action = handler == nil ? "Cleared" : "Installed"
        #log(
            "\(action, privacy: .public) subscribe handler; connection ID: \(self.identifier, privacy: .public)",
            category: .transport
        )
    }

    func setAskHandler(_ handler: (@Sendable (Event) async throws -> Event)?) {
        lock.withLock {
            askHandler = handler
        }
        let action = handler == nil ? "Cleared" : "Installed"
        #log(
            "\(action, privacy: .public) ask handler; connection ID: \(self.identifier, privacy: .public)",
            category: .transport
        )
    }

    func setCloseHandler(_ handler: (@Sendable () -> Void)?) {
        lock.withLock {
            closeHandler = handler
        }
        let action = handler == nil ? "Cleared" : "Installed"
        #log(
            "\(action, privacy: .public) close handler; connection ID: \(self.identifier, privacy: .public)",
            category: .transport
        )
    }

    func handshake(withReply reply: @escaping (Bool) -> Void) {
        let isClosed = lock.withLock { closed }
        #log(
            """
            Received XPC handshake; connection ID: \(self.identifier, privacy: .public), \
            closed: \(isClosed, privacy: .public)
            """,
            level: .info,
            category: .transport
        )
        reply(true)
    }

    func publish(_ data: Data) {
        let event: Event
        do {
            event = try EventCodec.decode(data)
        } catch {
            #log(
                """
                Failed to decode published event; connection ID: \(self.identifier, privacy: .public), \
                error: \(error.localizedDescription, privacy: .public)
                """,
                level: .error,
                category: .transport
            )
            return
        }

        let handler = lock.withLock { publishHandler }

        guard let handler else {
            #log(
                """
                Dropping published event because no handler is installed; \
                connection ID: \(self.identifier, privacy: .public)
                """,
                level: .warning,
                category: .transport
            )
            return
        }

        handler(event)
    }

    func subscribe(_ kindNames: [String], includeAll: Bool) {
        let handler = lock.withLock { subscribeHandler }

        guard let handler else {
            #log(
                """
                Dropping subscription because no handler is installed; \
                connection ID: \(self.identifier, privacy: .public), \
                include all: \(includeAll, privacy: .public), \
                requested kind count: \(kindNames.count, privacy: .public)
                """,
                level: .warning,
                category: .transport
            )
            return
        }

        if includeAll {
            #log(
                "Received subscription for all event kinds; connection ID: \(self.identifier, privacy: .public)",
                category: .transport
            )
            handler(nil)
            return
        }

        let kinds = Set(kindNames.compactMap { EventKind(rawValue: $0) })
        #log(
            """
            Received filtered subscription; connection ID: \(self.identifier, privacy: .public), \
            requested kind count: \(kindNames.count, privacy: .public), \
            recognized kind count: \(kinds.count, privacy: .public)
            """,
            category: .transport
        )
        handler(kinds)
    }

    func ask(_ data: Data, withReply reply: @escaping (Data?, Error?) -> Void) {
        let handler = lock.withLock { askHandler }
        let identifier = self.identifier

        nonisolated(unsafe) let reply = reply
        Task {
            let event: Event
            do {
                event = try EventCodec.decode(data)
            } catch {
                #log(
                    """
                    Failed to decode ask request; connection ID: \(identifier, privacy: .public), \
                    error: \(error.localizedDescription, privacy: .public)
                    """,
                    level: .error,
                    category: .transport
                )
                reply(nil, error)
                return
            }

            guard let handler else {
                #log(
                    "Rejecting ask because no handler is installed; connection ID: \(identifier, privacy: .public)",
                    level: .warning,
                    category: .transport
                )
                reply(nil, EventRemoteError.notConnected)
                return
            }

            do {
                let response = try await handler(event)
                let responseData = try EventCodec.encode(response)
                reply(responseData, nil)
            } catch {
                #log(
                    """
                    Ask failed; connection ID: \(identifier, privacy: .public), \
                    error: \(error.localizedDescription, privacy: .public)
                    """,
                    level: .error,
                    category: .transport
                )
                reply(nil, error)
            }
        }
    }

    func handleInvalidation() {
        let handler = lock.withLock { closeHandler }
        #log(
            """
            XPC transport server connection invalidated; connection ID: \(self.identifier, privacy: .public), \
            close handler installed: \(handler != nil, privacy: .public)
            """,
            level: .warning,
            category: .transport
        )
        handler?()
    }
}
