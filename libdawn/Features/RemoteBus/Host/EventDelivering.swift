public protocol EventDelivering: AnyObject, Sendable {
    func deliver(_ event: Event)
}
