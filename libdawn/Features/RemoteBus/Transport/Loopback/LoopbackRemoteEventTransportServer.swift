import Synchronization

public final class LoopbackRemoteEventTransportServer: RemoteEventTransportServer, @unchecked Sendable {
    private struct State: Sendable {
        var closed = false
        var publishHandler: (@Sendable (Event) -> Void)?
        var subscribeHandler: (@Sendable (Set<EventKind>?) -> Void)?
        var askHandler: (@Sendable (Event) async throws -> Event)?
        var closeHandler: (@Sendable () -> Void)?
    }

    weak var client: LoopbackRemoteEventTransportClient?
    private let state = Mutex(State())

    public func deliver(_ event: Event) {
        client?.receiveDeliver(event)
    }

    public func close() {
        let shouldClose = state.withLock { state in
            guard !state.closed else { return false }
            state.closed = true
            return true
        }
        guard shouldClose else { return }
        client?.close()
    }

    public func setPublishHandler(_ handler: (@Sendable (Event) -> Void)?) {
        state.withLock { $0.publishHandler = handler }
    }

    public func setSubscribeHandler(_ handler: (@Sendable (Set<EventKind>?) -> Void)?) {
        state.withLock { $0.subscribeHandler = handler }
    }

    public func setAskHandler(_ handler: (@Sendable (Event) async throws -> Event)?) {
        state.withLock { $0.askHandler = handler }
    }

    public func setCloseHandler(_ handler: (@Sendable () -> Void)?) {
        state.withLock { $0.closeHandler = handler }
    }

    func handlePublish(_ event: Event) {
        let handler = state.withLock { $0.publishHandler }
        handler?(event)
    }

    func handleSubscribe(_ kinds: Set<EventKind>?) {
        let handler = state.withLock { $0.subscribeHandler }
        handler?(kinds)
    }

    func handleAsk(_ event: Event) async throws -> Event {
        let handler = state.withLock { $0.askHandler }
        guard let handler else {
            throw EventRemoteError.notConnected
        }
        return try await handler(event)
    }

    func handleClose() {
        let handler = state.withLock { $0.closeHandler }
        handler?()
    }
}
