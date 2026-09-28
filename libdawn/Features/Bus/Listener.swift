@MainActor
public protocol Listener: AnyObject {
    func handle(_ event: PaEvent, reply: (@Sendable (PaEvent) -> Void)?)
}
