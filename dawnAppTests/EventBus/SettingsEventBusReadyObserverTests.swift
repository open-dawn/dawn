import Foundation
import Testing

@testable import dawnApp

@Suite("SettingsEventBusReadyObserver")
struct SettingsEventBusReadyObserverTests {
    @Test("Start delivers the ready ping")
    func startDeliversReadyPing() async throws {
        let notificationName = Notification.Name(
            "SettingsEventBusReadyObserverTests.\(UUID().uuidString)"
        )
        let received = ReadyPingCapture()
        let sut = SettingsEventBusReadyObserver(notificationName: notificationName)

        sut.start {
            Task { await received.record() }
        }
        defer { sut.stop() }

        DistributedNotificationCenter.default().postNotificationName(
            notificationName,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )

        try await Task.sleep(for: .milliseconds(200))

        #expect(await received.didReceive)
    }

    @Test("Stop ignores later ready pings")
    func stopIgnoresLaterPings() async throws {
        let notificationName = Notification.Name(
            "SettingsEventBusReadyObserverTests.\(UUID().uuidString)"
        )
        let received = ReadyPingCapture()
        let sut = SettingsEventBusReadyObserver(notificationName: notificationName)

        sut.start {
            Task { await received.record() }
        }
        sut.stop()

        DistributedNotificationCenter.default().postNotificationName(
            notificationName,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )

        try await Task.sleep(for: .milliseconds(200))

        #expect(await received.didReceive == false)
    }
}

private actor ReadyPingCapture {
    private(set) var didReceive = false

    func record() {
        didReceive = true
    }
}
