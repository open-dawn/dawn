public protocol RemoteEventTransportServer: EventDelivering {
    func close()
    func setPublishHandler(_ handler: (@Sendable (PaEvent) -> Void)?)
    func setSubscribeHandler(_ handler: (@Sendable (Set<PaEventKind>?) -> Void)?)
    func setAskHandler(_ handler: (@Sendable (PaEvent) async throws -> PaEvent)?)
    func setCloseHandler(_ handler: (@Sendable () -> Void)?)
}
