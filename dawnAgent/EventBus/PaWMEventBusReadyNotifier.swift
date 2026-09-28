import Foundation

struct dawnAgentEventBusReadyNotifier {
    private let notificationName: Notification.Name
    private let notificationCenter: DistributedNotificationCenter

    init(
        notificationName: Notification.Name = dawnAgentEventBusRendezvous.readyNotification,
        notificationCenter: DistributedNotificationCenter = .default()
    ) {
        self.notificationName = notificationName
        self.notificationCenter = notificationCenter
    }

    func postReady() {
        notificationCenter.postNotificationName(
            notificationName,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }
}
