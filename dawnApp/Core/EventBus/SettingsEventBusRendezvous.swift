import Foundation
import libdawn

enum SettingsEventBusRendezvous {
    static let machServiceName = EventBusMachService.serviceName
    static let readyNotification = Notification.Name(
        "app.opendawn.dawnAgent.eventBusReady"
    )
}
