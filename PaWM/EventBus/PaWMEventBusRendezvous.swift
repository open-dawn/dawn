import Foundation

enum PaWMEventBusRendezvous {
    static let machServiceName = "dev.longhi.pineappleinc.PaWM"
    static let readyNotification = Notification.Name(
        "dev.longhi.pineappleinc.PaWM.eventBusReady"
    )
}
