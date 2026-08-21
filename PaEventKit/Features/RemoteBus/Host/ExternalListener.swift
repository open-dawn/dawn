@MainActor
final class ExternalListener: Listener {
    weak var destination: EventDelivering?
    var kinds: Set<PaEventKind>?

    init(destination: EventDelivering, kinds: Set<PaEventKind>? = nil) {
        self.destination = destination
        self.kinds = kinds
    }

    func handle(_ event: PaEvent, reply: (@Sendable (PaEvent) -> Void)?) {
        if reply != nil {
            return
        }

        if let kinds, !kinds.contains(event.kind) {
            return
        }

        destination?.deliver(event)
    }
}
