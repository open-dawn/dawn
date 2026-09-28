import Foundation
import libdawn

@MainActor
final class dawnAgentEventBusRuntime {
    let bus: PaEventBus
    private let eventServer: PaEventServer
    private let acceptor: XPCRemoteEventTransportAcceptor

    init(
        bus: PaEventBus = PaEventBus(),
        machServiceName: String? = dawnAgentEventBusRendezvous.machServiceName
    ) {
        self.bus = bus
        let eventServer = PaEventServer(bus: bus)
        self.eventServer = eventServer
        self.acceptor = XPCRemoteEventTransportAcceptor(
            eventServer: eventServer,
            machServiceName: machServiceName
        )
    }

    @discardableResult
    func start() -> NSXPCListenerEndpoint? {
        acceptor.start()
        return acceptor.endpoint
    }

    func stop() {
        acceptor.stop()
        eventServer.stop()
    }
}
