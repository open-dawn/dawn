import Foundation
import Testing

@testable import dawnAgent

@Suite("dawnAgentEventBusReadyNotifier")
struct dawnAgentEventBusReadyNotifierTests {
    @Test("Post ready publishes an empty distributed notification")
    func postReadyPublishesEmptyNotification() async throws {
        let notificationName = Notification.Name("dawnAgentEventBusReadyNotifierTests.\(UUID().uuidString)")
        let received = ReadyNotificationCapture()

        let observer = DistributedNotificationCenter.default().addObserver(
            forName: notificationName,
            object: nil,
            queue: .main
        ) { notification in
            let snapshot = ReadyNotificationCapture.Snapshot(notification)
            Task {
                await received.record(snapshot)
            }
        }
        defer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }

        await MainActor.run {
            let sut = dawnAgentEventBusReadyNotifier(notificationName: notificationName)
            sut.postReady()
        }

        try await Task.sleep(for: .milliseconds(200))

        guard let snapshot = await received.recordedSnapshot() else {
            Issue.record("Expected ready notification")
            return
        }

        #expect(snapshot.objectIsNil)
        #expect(snapshot.userInfoIsNil)
    }
}

private actor ReadyNotificationCapture {
    struct Snapshot: Sendable {
        let objectIsNil: Bool
        let userInfoIsNil: Bool

        init(_ notification: Notification) {
            self.objectIsNil = notification.object == nil
            self.userInfoIsNil = notification.userInfo == nil
        }
    }

    private var snapshot: Snapshot?

    func record(_ snapshot: Snapshot) {
        self.snapshot = snapshot
    }

    func recordedSnapshot() -> Snapshot? {
        snapshot
    }
}
