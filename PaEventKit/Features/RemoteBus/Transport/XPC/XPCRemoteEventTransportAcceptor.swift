import Foundation

public final class XPCRemoteEventTransportAcceptor: NSObject, NSXPCListenerDelegate, @unchecked Sendable {
    private let eventServer: PaEventServer
    private var listener: NSXPCListener?
    private var transports: [XPCRemoteEventTransportServer] = []
    private let lock = NSLock()

    public init(eventServer: PaEventServer) {
        self.eventServer = eventServer
        super.init()
    }

    public var endpoint: NSXPCListenerEndpoint? {
        listener?.endpoint
    }

    public func start() {
        lock.lock()
        defer { lock.unlock() }

        guard listener == nil else { return }

        let listener = NSXPCListener.anonymous()
        listener.delegate = self
        listener.resume()
        self.listener = listener
    }

    public func stop() {
        lock.lock()
        let transports = self.transports
        self.transports = []
        let listener = self.listener
        self.listener = nil
        lock.unlock()

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

        connection.exportedInterface = NSXPCInterface(with: PaEventHostXPC.self)
        connection.remoteObjectInterface = NSXPCInterface(with: PaRemoteEventBusXPC.self)
        connection.exportedObject = transport
        connection.invalidationHandler = { [weak self, weak transport] in
            transport?.handleInvalidation()
            guard let self, let transport else { return }
            self.removeTransport(transport)
        }

        lock.lock()
        transports.append(transport)
        lock.unlock()

        eventServer.attach(transport)
        connection.resume()
        return true
    }

    private func removeTransport(_ transport: XPCRemoteEventTransportServer) {
        lock.lock()
        transports.removeAll { $0 === transport }
        lock.unlock()
    }
}
