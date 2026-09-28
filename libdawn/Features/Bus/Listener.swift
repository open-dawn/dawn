@MainActor
public protocol Listener: AnyObject {
    func handle(_ event: Event, reply: (@Sendable (Event) -> Void)?)
}
