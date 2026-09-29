import AppKit

public protocol RunningApplicationControlling {
    @discardableResult
    func activate(options: NSApplication.ActivationOptions) -> Bool

    @discardableResult
    func terminate() -> Bool

    @discardableResult
    func hide() -> Bool
}

extension NSRunningApplication: RunningApplicationControlling {}
