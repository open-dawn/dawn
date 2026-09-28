import Foundation
import libdawn

@MainActor
final class EventBusRuntime {
    let bus: EventBus
    private let eventServer: EventServer
    private let acceptor: XPCRemoteEventTransportAcceptor

    init(
        bus: EventBus = EventBus(),
        machServiceName: String? = EventBusRendezvous.machServiceName
    ) {
        self.bus = bus
        let eventServer = EventServer(bus: bus)
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
