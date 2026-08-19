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

@Test @MainActor func publishDeliversToMatchingListener() async throws {
    let bus = PaEventBus()
    let listener = TestListener()
    bus.addListener(listener, kinds: [.switchSpace])

    let event = PaEvent.switchSpace(PaSwitchSpaceEvent(spaceIndex: 1))
    bus.publish(event)

    try await Task.sleep(for: .milliseconds(50))

    #expect(listener.handledEvents == [event])
    #expect(listener.handledReplies == [false])
}

@Test @MainActor func publishRespectsKindFilter() async throws {
    let bus = PaEventBus()
    let listener = TestListener()
    bus.addListener(listener, kinds: [.debugPing])

    bus.publish(.switchSpace(PaSwitchSpaceEvent(spaceIndex: 1)))

    try await Task.sleep(for: .milliseconds(50))

    #expect(listener.handledEvents.isEmpty)
}

@Test @MainActor func askReturnsReplyFromHandler() async throws {
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

@Test @MainActor func askThrowsNoHandlerWhenNoListeners() async {
    let bus = PaEventBus()

    await #expect(throws: PaEventAskError.noHandler) {
        _ = try await bus.ask(.debugPing(PaDebugPingEvent()), timeout: .milliseconds(100))
    }
}

@Test @MainActor func askThrowsTimeoutWhenHandlerDoesNotReply() async {
    let bus = PaEventBus()
    let listener = TestListener()
    bus.addListener(listener, kinds: [.debugPing])

    await #expect(throws: PaEventAskError.timeout) {
        _ = try await bus.ask(.debugPing(PaDebugPingEvent()), timeout: .milliseconds(100))
    }
}

@Test @MainActor func askUsesFirstReplyOnly() async throws {
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
