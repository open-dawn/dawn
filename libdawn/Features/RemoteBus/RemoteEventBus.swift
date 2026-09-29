import Foundation

public final class RemoteEventBus: @unchecked Sendable {
    private struct Registration {
        weak var listener: Listener?
        let kinds: Set<EventKind>?
    }

    private let lock = NSLock()
    private let transport: any RemoteEventTransportClient
    private var registrations: [Registration] = []

    public init(transport: any RemoteEventTransportClient) {
        self.transport = transport
        transport.setDeliveryHandler { [weak self] event in
            self?.deliverFromHost(event)
        }
    }

    public var isConnected: Bool {
        transport.isConnected
    }

    public var connectionState: RemoteConnectionState {
        transport.connectionState
    }

    public func setConnectionStateHandler(
        _ handler: (@Sendable (RemoteConnectionState) -> Void)?
    ) {
        guard let handler else {
            transport.setConnectionStateHandler(nil)
            return
        }

        transport.setConnectionStateHandler { [weak self] state in
            handler(state)
            if state == .connected {
                self?.restoreSubscriptions()
            }
        }
    }

    public func disconnect() {
        transport.close()
    }

    public func attemptReconnect() async throws {
        try await transport.attemptReconnect()
        restoreSubscriptions()
    }

    public func addListener(_ listener: Listener, kinds: Set<EventKind>? = nil) {
        lock.withLock {
            pruneDeadRegistrationsLocked()
            registrations.append(Registration(listener: listener, kinds: kinds))
            syncSubscriptionLocked()
        }
    }

    public func removeListener(_ listener: Listener) {
        lock.withLock {
            registrations.removeAll { $0.listener === listener || $0.listener == nil }
            syncSubscriptionLocked()
        }
    }

    public func publish(_ event: Event) {
        transport.publish(event)
    }

    public func ask(
        _ event: Event,
        timeout: Duration = .seconds(5)
    ) async throws -> Event {
        guard transport.isConnected else {
            throw EventRemoteError.notConnected
        }

        return try await withCheckedThrowingContinuation { continuation in
            let session = AskSession(continuation: continuation)

            Task {
                try await Task.sleep(for: timeout)
                session.fail(with: EventAskError.timeout)
            }

            Task {
                do {
                    let response = try await transport.ask(event)
                    session.complete(with: response)
                } catch {
                    session.fail(with: error)
                }
            }
        }
    }

    func deliverFromHost(_ event: Event) {
        Task { @MainActor in
            for listener in matchingListeners(for: event.kind) {
                listener.handle(event, reply: nil)
            }
        }
    }

    private func restoreSubscriptions() {
        lock.withLock {
            syncSubscriptionLocked()
        }
    }

    private func syncSubscriptionLocked() {
        pruneDeadRegistrationsLocked()

        if registrations.contains(where: { $0.kinds == nil }) {
            transport.subscribe(kinds: nil)
            return
        }

        let kinds = Set(registrations.compactMap(\.kinds).flatMap { $0 })
        transport.subscribe(kinds: kinds)
    }

    private func matchingListeners(for kind: EventKind) -> [Listener] {
        return lock.withLock {
            pruneDeadRegistrationsLocked()

            return registrations.compactMap { registration in
                guard let listener = registration.listener else { return nil }
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
