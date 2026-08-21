import Foundation
import Testing
@testable import PaEventKit

@MainActor
private final class TestListener: Listener {
    private(set) var handledEvents: [PaEvent] = []
    private(set) var handledReplies: [Bool] = []
    var replyHandler: ((PaEvent, (@Sendable (PaEvent) -> Void)?) -> Void)?

    func handle(_ event: PaEvent, reply: (@Sendable (PaEvent) -> Void)?) {
        handledEvents.append(event)
        handledReplies.append(reply != nil)

        if let replyHandler {
            replyHandler(event, reply)
        }
    }
}

@Suite("PaEventBus")
@MainActor
struct PaEventBusTests {
    @Suite("Publish")
    @MainActor
    struct Publish {
        @Test func deliversToMatchingListener() async throws {
            let bus = PaEventBus()
            let listener = TestListener()
            bus.addListener(listener, kinds: [.switchSpace])

            let event = PaEvent.switchSpace(PaSwitchSpaceEvent(spaceIndex: 1))
            bus.publish(event)

            try await Task.sleep(for: .milliseconds(50))

            #expect(listener.handledEvents == [event])
            #expect(listener.handledReplies == [false])
        }

        @Test func respectsKindFilter() async throws {
            let bus = PaEventBus()
            let listener = TestListener()
            bus.addListener(listener, kinds: [.debugPing])

            bus.publish(.switchSpace(PaSwitchSpaceEvent(spaceIndex: 1)))

            try await Task.sleep(for: .milliseconds(50))

            #expect(listener.handledEvents.isEmpty)
        }

        @Test func deliversToPublishOnlyListener() async throws {
            let bus = PaEventBus()
            let listener = TestListener()
            bus.addPublishOnlyListener(listener, kinds: [.switchSpace])

            let event = PaEvent.switchSpace(PaSwitchSpaceEvent(spaceIndex: 1))
            bus.publish(event)

            try await Task.sleep(for: .milliseconds(50))

            #expect(listener.handledEvents == [event])
        }

        @Test func setListenerKindsUpdatesFilter() async throws {
            let bus = PaEventBus()
            let listener = TestListener()
            bus.addPublishOnlyListener(listener, kinds: [])

            bus.publish(.switchSpace(PaSwitchSpaceEvent(spaceIndex: 1)))
            try await Task.sleep(for: .milliseconds(50))
            #expect(listener.handledEvents.isEmpty)

            bus.setListenerKinds(listener, kinds: [.switchSpace])
            let event = PaEvent.switchSpace(PaSwitchSpaceEvent(spaceIndex: 2))
            bus.publish(event)
            try await Task.sleep(for: .milliseconds(50))
            #expect(listener.handledEvents == [event])
        }

        @Test func removeListenerStopsDelivery() async throws {
            let bus = PaEventBus()
            let listener = TestListener()
            bus.addListener(listener, kinds: [.switchSpace])

            let event = PaEvent.switchSpace(PaSwitchSpaceEvent(spaceIndex: 1))
            bus.publish(event)
            try await Task.sleep(for: .milliseconds(50))
            #expect(listener.handledEvents == [event])

            bus.removeListener(listener)
            bus.publish(.switchSpace(PaSwitchSpaceEvent(spaceIndex: 2)))
            try await Task.sleep(for: .milliseconds(50))
            #expect(listener.handledEvents == [event])
        }
    }

    @Suite("Ask")
    @MainActor
    struct Ask {
        @Test func returnsReplyFromHandler() async throws {
            let bus = PaEventBus()
            let listener = TestListener()
            listener.replyHandler = { event, reply in
                if case .debugPing = event {
                    reply?(.debugPong(PaDebugPongEvent(message: "ok")))
                }
            }
            bus.addListener(listener)

            let reply = try await bus.ask(.debugPing(PaDebugPingEvent()), timeout: .seconds(1))

            #expect(reply == .debugPong(PaDebugPongEvent(message: "ok")))
            #expect(listener.handledReplies == [true])
        }

        @Test func throwsNoHandlerWhenNoListeners() async {
            let bus = PaEventBus()

            await #expect(throws: PaEventAskError.noHandler) {
                _ = try await bus.ask(.debugPing(PaDebugPingEvent()), timeout: .milliseconds(100))
            }
        }

        @Test func throwsTimeoutWhenHandlerDoesNotReply() async {
            let bus = PaEventBus()
            let listener = TestListener()
            bus.addListener(listener, kinds: [.debugPing])

            await #expect(throws: PaEventAskError.timeout) {
                _ = try await bus.ask(.debugPing(PaDebugPingEvent()), timeout: .milliseconds(100))
            }
        }

        @Test func throwsNoHandlerWhenOnlyPublishOnlyListenerMatches() async {
            let bus = PaEventBus()
            let listener = TestListener()
            bus.addPublishOnlyListener(listener)

            await #expect(throws: PaEventAskError.noHandler) {
                _ = try await bus.ask(.debugPing(PaDebugPingEvent()), timeout: .milliseconds(100))
            }
        }

        @Test func usesFirstReplyOnly() async throws {
            let bus = PaEventBus()

            let first = TestListener()
            first.replyHandler = { _, reply in
                reply?(.debugPong(PaDebugPongEvent(message: "first")))
            }

            let second = TestListener()
            second.replyHandler = { _, reply in
                reply?(.debugPong(PaDebugPongEvent(message: "second")))
            }

            bus.addListener(first)
            bus.addListener(second)

            let reply = try await bus.ask(.debugPing(PaDebugPingEvent()), timeout: .seconds(1))

            #expect(reply == .debugPong(PaDebugPongEvent(message: "first")))
        }
    }
}
