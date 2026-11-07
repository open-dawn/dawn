import Foundation
import libdawn

enum EventBusRendezvous {
    static let machServiceName = EventBusMachService.serviceName
    static let readyNotification = Notification.Name(
        "app.opendawn.dawnAgent.eventBusReady"
    )
}
