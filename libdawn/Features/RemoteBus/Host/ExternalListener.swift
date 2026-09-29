@MainActor
final class ExternalListener: Listener {
    weak var destination: EventDelivering?
    var kinds: Set<EventKind>?

    init(destination: EventDelivering, kinds: Set<EventKind>? = nil) {
        self.destination = destination
        self.kinds = kinds
    }

    func handle(_ event: Event, reply: (@Sendable (Event) -> Void)?) {
        guard reply == nil else { return }

        guard kinds?.contains(event.kind) != false else { return }

        destination?.deliver(event)
    }
}
