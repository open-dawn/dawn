import libdawn

@MainActor
final class DebugPingListener: Listener {
    init(bus: EventBus) {
        bus.addListener(self, kinds: [.debugPing])
    }

    func handle(_ event: Event, reply: (@Sendable (Event) -> Void)?) {
        guard case .debugPing = event else { return }
        reply?(.debugPong(DebugPongEvent(message: "ok")))
    }
}
