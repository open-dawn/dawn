import Foundation

final class PaSettingsEventBusReadyObserver {
    private let notificationName: Notification.Name
    private let notificationCenter: DistributedNotificationCenter
    private var observer: NSObjectProtocol?

    init(
        notificationName: Notification.Name = PaSettingsEventBusRendezvous.readyNotification,
        notificationCenter: DistributedNotificationCenter = .default()
    ) {
        self.notificationName = notificationName
        self.notificationCenter = notificationCenter
    }

    func start(onReady: @escaping @Sendable () -> Void) {
        stop()

        observer = notificationCenter.addObserver(
            forName: notificationName,
            object: nil,
            queue: .main
        ) { _ in
            onReady()
        }
    }

    func stop() {
        if let observer {
            notificationCenter.removeObserver(observer)
            self.observer = nil
        }
    }

    deinit {
        stop()
    }
}
