import Foundation

enum SettingsEventBusRendezvous {
    static let machServiceName = "app.opendawn.dawnAgent"
    static let readyNotification = Notification.Name(
        "app.opendawn.dawnAgent.eventBusReady"
    )
}
