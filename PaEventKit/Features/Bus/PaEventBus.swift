import Foundation

public final class PaEventBus: @unchecked Sendable {
    private struct Registration {
        weak var listener: Listener?
        let kinds: Set<PaEventKind>?
    }

    private let lock = NSLock()
    private var registrations: [Registration] = []

    public init() {}

    public func addListener(_ listener: Listener, kinds: Set<PaEventKind>? = nil) {
        lock.lock()
        defer { lock.unlock() }

        pruneDeadRegistrationsLocked()
        registrations.append(Registration(listener: listener, kinds: kinds))
    }

    public func removeListener(_ listener: Listener) {
        lock.lock()
        defer { lock.unlock() }

        registrations.removeAll { $0.listener === listener || $0.listener == nil }
    }

    public func publish(_ event: PaEvent) {
        let listeners = matchingListeners(for: event.kind)

        Task { @MainActor in
            for listener in listeners {
                listener.handle(event, reply: nil)
            }
        }
    }

    public func ask(
        _ event: PaEvent,
        timeout: Duration = .seconds(5)
    ) async throws -> PaEvent {
        let listeners = matchingListeners(for: event.kind)
        guard !listeners.isEmpty else {
            throw PaEventAskError.noHandler
        }

        return try await withCheckedThrowingContinuation { continuation in
            let session = AskSession(continuation: continuation)

            let reply: @Sendable (PaEvent) -> Void = { response in
                session.complete(with: response)
            }

            Task {
                try await Task.sleep(for: timeout)
                session.fail(with: PaEventAskError.timeout)
            }

            Task { @MainActor in
                for listener in listeners {
                    listener.handle(event, reply: reply)
                }
            }
        }
    }

    private func matchingListeners(for kind: PaEventKind) -> [Listener] {
        lock.lock()
        defer { lock.unlock() }

        pruneDeadRegistrationsLocked()

        return registrations.compactMap { registration in
            guard let listener = registration.listener else { return nil }
            guard registration.kinds == nil || registration.kinds!.contains(kind) else {
                return nil
            }
            return listener
        }
    }

    private func pruneDeadRegistrationsLocked() {
        registrations.removeAll { $0.listener == nil }
    }
}
