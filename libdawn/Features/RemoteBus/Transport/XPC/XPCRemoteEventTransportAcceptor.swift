import Foundation

public final class XPCRemoteEventTransportAcceptor: NSObject, NSXPCListenerDelegate, @unchecked Sendable {
    private let eventServer: EventServer
    private let machServiceName: String?
    private var listener: NSXPCListener?
    private var transports: [XPCRemoteEventTransportServer] = []
    private let lock = NSLock()

    public init(eventServer: EventServer, machServiceName: String? = nil) {
        self.eventServer = eventServer
        self.machServiceName = machServiceName
        super.init()
    }

    public var endpoint: NSXPCListenerEndpoint? {
        listener?.endpoint
    }

    public func start() {
        lock.withLock {
            guard listener == nil else { return }

            let listener: NSXPCListener
            if let machServiceName {
                listener = NSXPCListener(machServiceName: machServiceName)
            } else {
                listener = NSXPCListener.anonymous()
            }
            listener.delegate = self
            listener.resume()
            self.listener = listener
        }
    }

    public func stop() {
        let (transports, listener) = lock.withLock {
            let transports = self.transports
            self.transports = []
            let listener = self.listener
            self.listener = nil
            return (transports, listener)
        }

        listener?.invalidate()
        for transport in transports {
            eventServer.detach(transport)
        }
    }

    public func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection connection: NSXPCConnection
    ) -> Bool {
        let transport = XPCRemoteEventTransportServer(connection: connection)

        connection.exportedInterface = NSXPCInterface(with: EventHostXPC.self)
        connection.remoteObjectInterface = NSXPCInterface(with: RemoteEventBusXPC.self)
        connection.exportedObject = transport
        connection.invalidationHandler = { [weak self, weak transport] in
            transport?.handleInvalidation()
            guard let self, let transport else { return }
            self.removeTransport(transport)
        }

        lock.withLock {
            transports.append(transport)
        }

        eventServer.attach(transport)
        connection.resume()
        return true
    }

    private func removeTransport(_ transport: XPCRemoteEventTransportServer) {
        lock.withLock {
            transports.removeAll { $0 === transport }
        }
    }
}
