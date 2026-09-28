import Foundation

enum dawnAgentEventBusRendezvous {
    static let machServiceName = "app.opendawn.dawnAgent"
    static let readyNotification = Notification.Name(
        "app.opendawn.dawnAgent.eventBusReady"
    )
}
