import Foundation

public final class EventBus: @unchecked Sendable {
    private struct Registration {
        weak var listener: Listener?
        var kinds: Set<EventKind>?
        let receivesAsks: Bool
    }

    private let lock: NSLock
    private var registrations: [Registration]

    public init() {
        lock = NSLock()
        registrations = []
    }

    public func addListener(_ listener: Listener, kinds: Set<EventKind>? = nil) {
        register(listener, kinds: kinds, receivesAsks: true)
    }

    func addPublishOnlyListener(_ listener: Listener, kinds: Set<EventKind>? = nil) {
        register(listener, kinds: kinds, receivesAsks: false)
    }

    func setListenerKinds(_ listener: Listener, kinds: Set<EventKind>?) {
        lock.withLock {
            guard let index = registrations.firstIndex(where: { $0.listener === listener }) else {
                return
            }
            registrations[index].kinds = kinds
        }
    }

    private func register(
        _ listener: Listener,
        kinds: Set<EventKind>?,
        receivesAsks: Bool
    ) {
        lock.withLock {
            pruneDeadRegistrationsLocked()
            registrations.append(
                Registration(listener: listener, kinds: kinds, receivesAsks: receivesAsks)
            )
        }
    }

    public func removeListener(_ listener: Listener) {
        lock.withLock {
            registrations.removeAll { $0.listener === listener || $0.listener == nil }
        }
    }

    public func publish(_ event: Event) {
        Task { @MainActor in
            for listener in matchingListeners(for: event.kind) {
                listener.handle(event, reply: nil)
            }
        }
    }

    public func hasListeners(for event: Event? = nil) -> Bool {
        if let event {
            return !(matchingListeners(for: event.kind).isEmpty)
        }

        return lock.withLock {
            pruneDeadRegistrationsLocked()
            return !registrations.isEmpty
        }
    }

    public func ask(
        _ event: Event,
        timeout: Duration = .seconds(5)
    ) async throws -> Event {
        guard !matchingListeners(for: event.kind, includingPublishOnly: false).isEmpty else {
            throw EventAskError.noHandler
        }

        return try await withCheckedThrowingContinuation { continuation in
            let session = AskSession(continuation: continuation)

            let reply: @Sendable (Event) -> Void = { response in
                session.complete(with: response)
            }

            Task {
                try await Task.sleep(for: timeout)
                session.fail(with: EventAskError.timeout)
            }

            Task { @MainActor in
                for listener in matchingListeners(for: event.kind, includingPublishOnly: false) {
                    listener.handle(event, reply: reply)
                }
            }
        }
    }

    private func matchingListeners(
        for kind: EventKind,
        includingPublishOnly: Bool = true
    ) -> [Listener] {
        return lock.withLock {
            pruneDeadRegistrationsLocked()

            return registrations.compactMap { registration in
                guard let listener = registration.listener else { return nil }
                guard includingPublishOnly || registration.receivesAsks else { return nil }
                guard registration.kinds == nil || registration.kinds!.contains(kind) else {
                    return nil
                }
                return listener
            }
        }
    }

    private func pruneDeadRegistrationsLocked() {
        registrations.removeAll { $0.listener == nil }
    }
}
