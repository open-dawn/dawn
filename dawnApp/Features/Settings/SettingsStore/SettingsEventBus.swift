import libdawn

@MainActor
protocol SettingsEventBus: AnyObject {
    func addListener(_ listener: Listener, kinds: Set<EventKind>?)
    func removeListener(_ listener: Listener)
    func ask(_ event: Event, timeout: Duration) async throws -> Event
}

extension RemoteEventBus: SettingsEventBus {}
