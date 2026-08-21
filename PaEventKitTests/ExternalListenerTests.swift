import Foundation
import Testing
@testable import PaEventKit

private final class MockEventDelivering: EventDelivering, @unchecked Sendable {
    private let lock = NSLock()
    private var events: [PaEvent] = []

    func deliver(_ event: PaEvent) {
        lock.lock()
        events.append(event)
        lock.unlock()
    }

    func deliveredEvents() -> [PaEvent] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }
}

@Suite("ExternalListener")
@MainActor
struct ExternalListenerTests {
    @Test func deliversPublishEvents() {
        let destination = MockEventDelivering()
        let listener = ExternalListener(destination: destination, kinds: [.switchSpace])

        listener.handle(.switchSpace(PaSwitchSpaceEvent(spaceIndex: 1)), reply: nil)

        #expect(destination.deliveredEvents() == [.switchSpace(PaSwitchSpaceEvent(spaceIndex: 1))])
    }

    @Test func respectsKindFilter() {
        let destination = MockEventDelivering()
        let listener = ExternalListener(destination: destination, kinds: [.debugPing])

        listener.handle(.switchSpace(PaSwitchSpaceEvent(spaceIndex: 1)), reply: nil)

        #expect(destination.deliveredEvents().isEmpty)
    }

    @Test func doesNotDeliverAskReplies() {
        let destination = MockEventDelivering()
        let listener = ExternalListener(destination: destination)

        listener.handle(.debugPing(PaDebugPingEvent()), reply: { _ in })

        #expect(destination.deliveredEvents().isEmpty)
    }
}
