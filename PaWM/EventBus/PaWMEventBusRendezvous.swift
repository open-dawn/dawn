import Foundation

enum PaWMEventBusRendezvous {
    static let machServiceName = "app.opendawn.PaWM"
    static let readyNotification = Notification.Name(
        "app.opendawn.PaWM.eventBusReady"
    )
}
