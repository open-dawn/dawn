import Foundation
import libdawn

@MainActor
final class EventBusRuntime {
    private enum Acceptor {
        case xpc(XPCRemoteEventTransportAcceptor)
        case distributedNotification(DistributedRemoteEventTransportAcceptor)
    }

    let bus: EventBus
    private let eventServer: EventServer
    private let acceptor: Acceptor

    init(
        bus: EventBus = EventBus(),
        machServiceName: String? = EventBusRendezvous.machServiceName
    ) {
        self.bus = bus
        let eventServer = EventServer(bus: bus)
        self.eventServer = eventServer
        self.acceptor = .xpc(XPCRemoteEventTransportAcceptor(
            eventServer: eventServer,
            machServiceName: machServiceName
        ))
    }

    init(
        bus: EventBus = EventBus(),
        distributedNotificationServiceName: String
    ) {
        self.bus = bus
        let eventServer = EventServer(bus: bus)
        self.eventServer = eventServer
        self.acceptor = .distributedNotification(
            DistributedRemoteEventTransportAcceptor(
                eventServer: eventServer,
                serviceName: distributedNotificationServiceName
            )
        )
    }

    @discardableResult
    func start() -> NSXPCListenerEndpoint? {
        switch acceptor {
        case let .xpc(acceptor):
            acceptor.start()
            return acceptor.endpoint
        case let .distributedNotification(acceptor):
            acceptor.start()
            return nil
        }
    }

    func stop() {
        switch acceptor {
        case let .xpc(acceptor):
            acceptor.stop()
        case let .distributedNotification(acceptor):
            acceptor.stop()
        }
        eventServer.stop()
    }
}
