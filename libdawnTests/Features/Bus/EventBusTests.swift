import Foundation
import Testing
@testable import libdawn

@MainActor
private final class TestListener: Listener {
    private(set) var handledEvents: [Event] = []
    private(set) var handledReplies: [Bool] = []
    var replyHandler: ((Event, (@Sendable (Event) -> Void)?) -> Void)?

    func handle(_ event: Event, reply: (@Sendable (Event) -> Void)?) {
        handledEvents.append(event)
        handledReplies.append(reply != nil)

        if let replyHandler {
            replyHandler(event, reply)
        }
    }
}

@Suite("EventBus")
@MainActor
struct EventBusTests {
    @Suite("Publish")
    @MainActor
    struct Publish {
        @Test("delivers to matching listener")
        func deliversToMatchingListener() async throws {
            let bus = EventBus()
            let listener = TestListener()
            bus.addListener(listener, kinds: [.switchSpace])

            let event = Event.switchSpace(SwitchSpaceEvent(spaceIndex: 1))
            bus.publish(event)

            try await Task.sleep(for: .milliseconds(50))

            #expect(listener.handledEvents == [event])
            #expect(listener.handledReplies == [false])
        }

        @Test("ignores unsubscribed kinds")
        func respectsKindFilter() async throws {
            let bus = EventBus()
            let listener = TestListener()
            bus.addListener(listener, kinds: [.debugPing])

            bus.publish(.switchSpace(SwitchSpaceEvent(spaceIndex: 1)))

            try await Task.sleep(for: .milliseconds(50))

            #expect(listener.handledEvents.isEmpty)
        }

        @Test("nil filter delivers all kinds")
        func deliversAllKindsWhenFilterIsNil() async throws {
            let bus = EventBus()
            let listener = TestListener()
            bus.addListener(listener)

            let ping = Event.debugPing(DebugPingEvent())
            let space = Event.switchSpace(SwitchSpaceEvent(spaceIndex: 1))
            bus.publish(ping)
            bus.publish(space)

            try await Task.sleep(for: .milliseconds(50))

            #expect(listener.handledEvents == [ping, space])
        }

        @Test("drops deallocated listeners")
        func dropsDeallocatedListener() async throws {
            let bus = EventBus()
            let remaining = TestListener()
            bus.addListener(remaining, kinds: [.switchSpace])

            var ephemeral: TestListener? = TestListener()
            bus.addListener(ephemeral!, kinds: [.switchSpace])
            weak let weakEphemeral = ephemeral
            ephemeral = nil

            #expect(weakEphemeral == nil)

            let event = Event.switchSpace(SwitchSpaceEvent(spaceIndex: 1))
            bus.publish(event)

            try await Task.sleep(for: .milliseconds(50))

            #expect(remaining.handledEvents == [event])
        }

        @Test("setListenerKinds ignores unknown listener")
        func setListenerKindsIgnoresUnknownListener() async throws {
            let bus = EventBus()
            let unknown = TestListener()
            bus.setListenerKinds(unknown, kinds: [.switchSpace])

            let listener = TestListener()
            bus.addListener(listener, kinds: [])

            bus.publish(.switchSpace(SwitchSpaceEvent(spaceIndex: 1)))

            try await Task.sleep(for: .milliseconds(50))

            #expect(unknown.handledEvents.isEmpty)
            #expect(listener.handledEvents.isEmpty)
        }

        @Test("delivers to publish-only listener")
        func deliversToPublishOnlyListener() async throws {
            let bus = EventBus()
            let listener = TestListener()
            bus.addPublishOnlyListener(listener, kinds: [.switchSpace])

            let event = Event.switchSpace(SwitchSpaceEvent(spaceIndex: 1))
            bus.publish(event)

            try await Task.sleep(for: .milliseconds(50))

            #expect(listener.handledEvents == [event])
        }

        @Test("setListenerKinds updates the filter")
        func setListenerKindsUpdatesFilter() async throws {
            let bus = EventBus()
            let listener = TestListener()
            bus.addPublishOnlyListener(listener, kinds: [])

            bus.publish(.switchSpace(SwitchSpaceEvent(spaceIndex: 1)))
            try await Task.sleep(for: .milliseconds(50))
            #expect(listener.handledEvents.isEmpty)

            bus.setListenerKinds(listener, kinds: [.switchSpace])
            let event = Event.switchSpace(SwitchSpaceEvent(spaceIndex: 2))
            bus.publish(event)

            try await Task.sleep(for: .milliseconds(50))

            #expect(listener.handledEvents == [event])
        }

        @Test("removeListener stops delivery")
        func removeListenerStopsDelivery() async throws {
            let bus = EventBus()
            let listener = TestListener()
            bus.addListener(listener, kinds: [.switchSpace])

            let event = Event.switchSpace(SwitchSpaceEvent(spaceIndex: 1))
            bus.publish(event)

            try await Task.sleep(for: .milliseconds(50))

            #expect(listener.handledEvents == [event])

            bus.removeListener(listener)
            bus.publish(.switchSpace(SwitchSpaceEvent(spaceIndex: 2)))

            try await Task.sleep(for: .milliseconds(50))

            #expect(listener.handledEvents == [event])
        }
    }

    @Suite("Ask")
    @MainActor
    struct Ask {
        @Test("ask returns the handler reply")
        func returnsReplyFromHandler() async throws {
            let bus = EventBus()
            let listener = TestListener()
            listener.replyHandler = { event, reply in
                if case .debugPing = event {
                    reply?(.debugPong(DebugPongEvent(message: "ok")))
                }
            }
            bus.addListener(listener)

            let reply = try await bus.ask(.debugPing(DebugPingEvent()), timeout: .seconds(1))

            #expect(reply == .debugPong(DebugPongEvent(message: "ok")))
            #expect(listener.handledReplies == [true])
        }

        @Test("ask throws noHandler with no listeners")
        func throwsNoHandlerWhenNoListeners() async {
            let bus = EventBus()

            await #expect(throws: EventAskError.noHandler) {
                _ = try await bus.ask(.debugPing(DebugPingEvent()), timeout: .milliseconds(100))
            }
        }

        @Test("ask throws timeout when handler does not reply")
        func throwsTimeoutWhenHandlerDoesNotReply() async {
            let bus = EventBus()
            let listener = TestListener()
            bus.addListener(listener, kinds: [.debugPing])

            await #expect(throws: EventAskError.timeout) {
                _ = try await bus.ask(.debugPing(DebugPingEvent()), timeout: .milliseconds(100))
            }
        }

        @Test("ask throws noHandler for publish-only listeners")
        func throwsNoHandlerWhenOnlyPublishOnlyListenerMatches() async {
            let bus = EventBus()
            let listener = TestListener()
            bus.addPublishOnlyListener(listener)

            await #expect(throws: EventAskError.noHandler) {
                _ = try await bus.ask(.debugPing(DebugPingEvent()), timeout: .milliseconds(100))
            }
        }

        @Test("ask uses the first reply only")
        func usesFirstReplyOnly() async throws {
            let bus = EventBus()

            let first = TestListener()
            first.replyHandler = { _, reply in
                reply?(.debugPong(DebugPongEvent(message: "first")))
            }

            let second = TestListener()
            second.replyHandler = { _, reply in
                reply?(.debugPong(DebugPongEvent(message: "second")))
            }

            bus.addListener(first)
            bus.addListener(second)

            let reply = try await bus.ask(.debugPing(DebugPingEvent()), timeout: .seconds(1))

            #expect(reply == .debugPong(DebugPongEvent(message: "first")))
        }
    }
}
