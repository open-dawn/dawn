public protocol RemoteEventTransportClient: AnyObject, Sendable {
    var isConnected: Bool { get }

    func setDeliveryHandler(_ handler: @escaping @Sendable (PaEvent) -> Void)
    func publish(_ event: PaEvent)
    func subscribe(kinds: Set<PaEventKind>?)
    func ask(_ event: PaEvent) async throws -> PaEvent
    func close()
}
