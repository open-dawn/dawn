public protocol RemoteEventTransportClient: AnyObject, Sendable {
    var isConnected: Bool { get }
    var connectionState: RemoteConnectionState { get }

    func setDeliveryHandler(_ handler: @escaping @Sendable (Event) -> Void)
    func setConnectionStateHandler(
        _ handler: (@Sendable (RemoteConnectionState) -> Void)?
    )
    func publish(_ event: Event)
    func subscribe(kinds: Set<EventKind>?)
    func ask(_ event: Event) async throws -> Event
    func attemptReconnect() async throws
    func close()
}
