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

        #expect(fixture.readyCapture.didReceive)
        #expect(fixture.readyCapture.objectIsNil)
        #expect(fixture.readyCapture.userInfoIsNil)
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
        #expect(fixture.readyCapture.didReceive)

        fixture.readyCapture.reset()

        fixture.service.start()
        try await Task.sleep(for: .milliseconds(200))

        #expect(fixture.readyCapture.didReceive)
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
            readyCapture.record(
                object: notification.object,
                userInfo: notification.userInfo
            )
        }
    }

    func cleanUp() {
        service.stop()
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }
}

private final class ServiceReadyCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var _didReceive = false
    private var _objectIsNil = false
    private var _userInfoIsNil = false

    var didReceive: Bool {
        lock.withLock { _didReceive }
    }

    var objectIsNil: Bool {
        lock.withLock { _objectIsNil }
    }

    var userInfoIsNil: Bool {
        lock.withLock { _userInfoIsNil }
    }

    func record(object: Any?, userInfo: [AnyHashable: Any]?) {
        lock.withLock {
            _didReceive = true
            _objectIsNil = object == nil
            _userInfoIsNil = userInfo == nil
        }
    }

    func reset() {
        lock.withLock {
            _didReceive = false
            _objectIsNil = false
            _userInfoIsNil = false
        }
    }
}
