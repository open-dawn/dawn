import Foundation

enum PaSettingsEventBusRendezvous {
    static let machServiceName = "app.opendawn.PaWM"
    static let readyNotification = Notification.Name(
        "app.opendawn.eventBusReady"
    )
}
