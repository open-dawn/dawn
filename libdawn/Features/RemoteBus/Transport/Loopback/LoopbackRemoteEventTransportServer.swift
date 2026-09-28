import Synchronization

public final class LoopbackRemoteEventTransportServer: RemoteEventTransportServer, @unchecked Sendable {
    private struct State: Sendable {
        var closed = false
        var publishHandler: (@Sendable (PaEvent) -> Void)?
        var subscribeHandler: (@Sendable (Set<PaEventKind>?) -> Void)?
        var askHandler: (@Sendable (PaEvent) async throws -> PaEvent)?
        var closeHandler: (@Sendable () -> Void)?
    }

    weak var client: LoopbackRemoteEventTransportClient?
    private let state = Mutex(State())

    public func deliver(_ event: PaEvent) {
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

    public func setPublishHandler(_ handler: (@Sendable (PaEvent) -> Void)?) {
        state.withLock { $0.publishHandler = handler }
    }

    public func setSubscribeHandler(_ handler: (@Sendable (Set<PaEventKind>?) -> Void)?) {
        state.withLock { $0.subscribeHandler = handler }
    }

    public func setAskHandler(_ handler: (@Sendable (PaEvent) async throws -> PaEvent)?) {
        state.withLock { $0.askHandler = handler }
    }

    public func setCloseHandler(_ handler: (@Sendable () -> Void)?) {
        state.withLock { $0.closeHandler = handler }
    }

    func handlePublish(_ event: PaEvent) {
        let handler = state.withLock { $0.publishHandler }
        handler?(event)
    }

    func handleSubscribe(_ kinds: Set<PaEventKind>?) {
        let handler = state.withLock { $0.subscribeHandler }
        handler?(kinds)
    }

    func handleAsk(_ event: PaEvent) async throws -> PaEvent {
        let handler = state.withLock { $0.askHandler }
        guard let handler else {
            throw PaEventRemoteError.notConnected
        }
        return try await handler(event)
    }

    func handleClose() {
        let handler = state.withLock { $0.closeHandler }
        handler?()
    }
}
