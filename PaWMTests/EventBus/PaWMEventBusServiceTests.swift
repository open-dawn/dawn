import Foundation
import PaEventKit
import Testing

@testable import PaWM

@MainActor
@Suite("PaWMEventBusService")
struct PaWMEventBusServiceTests {
    @Test("Start posts the ready notification")
    func startPostsReady() async throws {
        let fixture = ServiceFixture()
        defer { fixture.cleanUp() }

        fixture.service.start()

        try await Task.sleep(for: .milliseconds(200))

        guard let snapshot = await fixture.readyCapture.recordedSnapshot() else {
            Issue.record("Expected ready notification")
            return
        }

        #expect(snapshot.objectIsNil)
        #expect(snapshot.userInfoIsNil)
    }

    @Test("Bus matches the runtime bus instance")
    func busMatchesRuntimeBus() async throws {
        let runtime = PaWMEventBusRuntime(machServiceName: nil)
        let fixture = ServiceFixture(runtime: runtime)
        defer { fixture.cleanUp() }

        #expect(fixture.service.bus === runtime.bus)
    }

    @Test("Second start posts ready again")
    func secondStartPostsReadyAgain() async throws {
        let fixture = ServiceFixture()
        defer { fixture.cleanUp() }

        fixture.service.start()
        try await Task.sleep(for: .milliseconds(200))
        #expect(await fixture.readyCapture.recordedSnapshot() != nil)

        await fixture.readyCapture.reset()

        fixture.service.start()
        try await Task.sleep(for: .milliseconds(200))

        #expect(await fixture.readyCapture.recordedSnapshot() != nil)
    }
}

@MainActor
private struct ServiceFixture {
    let readyCapture: ServiceReadyCapture
    let service: PaWMEventBusService
    private var observer: NSObjectProtocol?

    init(runtime: PaWMEventBusRuntime = PaWMEventBusRuntime(machServiceName: nil)) {
        let notificationName = Notification.Name(
            "PaWMEventBusServiceTests.\(UUID().uuidString).ready"
        )
        let readyCapture = ServiceReadyCapture()

        self.readyCapture = readyCapture
        self.service = PaWMEventBusService(
            runtime: runtime,
            readyNotifier: PaWMEventBusReadyNotifier(notificationName: notificationName)
        )

        observer = DistributedNotificationCenter.default().addObserver(
            forName: notificationName,
            object: nil,
            queue: .main
        ) { notification in
            let snapshot = ServiceReadyCapture.Snapshot(notification)
            Task {
                await readyCapture.record(snapshot)
            }
        }
    }

    func cleanUp() {
        service.stop()
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }
}

private actor ServiceReadyCapture {
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

    func reset() {
        snapshot = nil
    }
}
