import Foundation
import PaEventKit

@MainActor
final class PaWMEventBusRuntime {
    let bus: PaEventBus
    private let eventServer: PaEventServer
    private let acceptor: XPCRemoteEventTransportAcceptor

    init(
        bus: PaEventBus = PaEventBus(),
        machServiceName: String? = PaWMEventBusRendezvous.machServiceName
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
