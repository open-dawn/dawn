@MainActor
final class ExternalListener: Listener {
    weak var destination: EventDelivering?
    var kinds: Set<PaEventKind>?

    init(destination: EventDelivering, kinds: Set<PaEventKind>? = nil) {
        self.destination = destination
        self.kinds = kinds
    }

    func handle(_ event: PaEvent, reply: (@Sendable (PaEvent) -> Void)?) {
        guard reply == nil else { return }

        guard kinds?.contains(event.kind) != false else { return }

        destination?.deliver(event)
    }
}
