import AppKit

public protocol RunningApplicationControlling {
    var bundleIdentifier: String? { get }
    var activationPolicy: NSApplication.ActivationPolicy { get }
    var isHidden: Bool { get }

    @discardableResult
    func activate(options: NSApplication.ActivationOptions) -> Bool

    @discardableResult
    func terminate() -> Bool

    @discardableResult
    func hide() -> Bool

    @discardableResult
    func unhide() -> Bool
}

extension NSRunningApplication: RunningApplicationControlling {}
