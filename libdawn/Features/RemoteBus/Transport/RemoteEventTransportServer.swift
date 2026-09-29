public protocol RemoteEventTransportServer: EventDelivering {
    func close()
    func setPublishHandler(_ handler: (@Sendable (Event) -> Void)?)
    func setSubscribeHandler(_ handler: (@Sendable (Set<EventKind>?) -> Void)?)
    func setAskHandler(_ handler: (@Sendable (Event) async throws -> Event)?)
    func setCloseHandler(_ handler: (@Sendable () -> Void)?)
}
