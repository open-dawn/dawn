public protocol RemoteEventTransportClient: AnyObject, Sendable {
    var isConnected: Bool { get }
    var connectionState: PaRemoteConnectionState { get }

    func setDeliveryHandler(_ handler: @escaping @Sendable (PaEvent) -> Void)
    func setConnectionStateHandler(
        _ handler: (@Sendable (PaRemoteConnectionState) -> Void)?
    )
    func publish(_ event: PaEvent)
    func subscribe(kinds: Set<PaEventKind>?)
    func ask(_ event: PaEvent) async throws -> PaEvent
    func attemptReconnect() async throws
    func close()
}
