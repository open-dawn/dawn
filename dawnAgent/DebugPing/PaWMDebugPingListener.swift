import PaEventKit

@MainActor
final class PaWMDebugPingListener: Listener {
    init(bus: PaEventBus) {
        bus.addListener(self, kinds: [.debugPing])
    }

    func handle(_ event: PaEvent, reply: (@Sendable (PaEvent) -> Void)?) {
        guard case .debugPing = event else { return }
        reply?(.debugPong(PaDebugPongEvent(message: "ok")))
    }
}
