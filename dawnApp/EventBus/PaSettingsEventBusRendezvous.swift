import Foundation

enum PaSettingsEventBusRendezvous {
    static let machServiceName = "app.opendawn.dawnAgent"
    static let readyNotification = Notification.Name(
        "app.opendawn.eventBusReady"
    )
}
