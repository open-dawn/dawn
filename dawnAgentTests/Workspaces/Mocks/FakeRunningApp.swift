import AppKit
@testable import PaWM

final class FakeRunningApp: RunningApplicationControlling {
    var activateResult = true
    var terminateResult = true
    var hideResult = true

    @discardableResult
    func activate(options _: NSApplication.ActivationOptions) -> Bool {
        return activateResult
    }

    @discardableResult
    func terminate() -> Bool {
        return terminateResult
    }

    @discardableResult
    func hide() -> Bool {
        return hideResult
    }
}
