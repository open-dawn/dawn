import Foundation

struct PaWMEventBusReadyNotifier {
    private let notificationName: Notification.Name
    private let notificationCenter: DistributedNotificationCenter

    init(
        notificationName: Notification.Name = PaWMEventBusRendezvous.readyNotification,
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
