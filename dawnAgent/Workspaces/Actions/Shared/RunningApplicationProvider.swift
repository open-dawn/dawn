import AppKit

public protocol RunningApplicationControlling {
    var bundleIdentifier: String? { get }
    var activationPolicy: NSApplication.ActivationPolicy { get }

    @discardableResult
    func activate(options: NSApplication.ActivationOptions) -> Bool

    @discardableResult
    func terminate() -> Bool

    @discardableResult
    func hide() -> Bool
}

extension NSRunningApplication: RunningApplicationControlling {}
