import Foundation
import Testing
@testable import libdawn

private final class MockEventDelivering: EventDelivering, @unchecked Sendable {
    private let lock = NSLock()
    private var events: [PaEvent] = []

    func deliver(_ event: PaEvent) {
        lock.withLock {
            events.append(event)
        }
    }

    func deliveredEvents() -> [PaEvent] {
        lock.withLock { events }
    }
}

@Suite("ExternalListener")
@MainActor
struct ExternalListenerTests {
    @Test("delivers matching publish events")
    func deliversPublishEvents() {
        let destination = MockEventDelivering()
        let listener = ExternalListener(destination: destination, kinds: [.switchSpace])

        listener.handle(.switchSpace(PaSwitchSpaceEvent(spaceIndex: 1)), reply: nil)

        #expect(destination.deliveredEvents() == [.switchSpace(PaSwitchSpaceEvent(spaceIndex: 1))])
    }

    @Test("ignores unsubscribed kinds")
    func respectsKindFilter() {
        let destination = MockEventDelivering()
        let listener = ExternalListener(destination: destination, kinds: [.debugPing])

        listener.handle(.switchSpace(PaSwitchSpaceEvent(spaceIndex: 1)), reply: nil)

        #expect(destination.deliveredEvents().isEmpty)
    }

    @Test("nil filter delivers all kinds")
    func deliversAllKindsWhenFilterIsNil() {
        let destination = MockEventDelivering()
        let listener = ExternalListener(destination: destination)

        listener.handle(.switchSpace(PaSwitchSpaceEvent(spaceIndex: 1)), reply: nil)
        listener.handle(.debugPing(PaDebugPingEvent()), reply: nil)

        #expect(destination.deliveredEvents() == [
            .switchSpace(PaSwitchSpaceEvent(spaceIndex: 1)),
            .debugPing(PaDebugPingEvent())
        ])
    }

    @Test("does not deliver ask replies")
    func doesNotDeliverAskReplies() {
        let destination = MockEventDelivering()
        let listener = ExternalListener(destination: destination)

        listener.handle(.debugPing(PaDebugPingEvent()), reply: { _ in })

        #expect(destination.deliveredEvents().isEmpty)
    }
}
