import AppKit
@testable import dawnAgent

final class FakeRunningApp: RunningApplicationControlling {
    var bundleIdentifier: String?
    var activateResult = true
    var terminateResult = true
    var hideResult = true

    private(set) var activateCallCount = 0
    private(set) var terminateCallCount = 0
    private(set) var hideCallCount = 0

    init(bundleIdentifier: String? = nil) {
        self.bundleIdentifier = bundleIdentifier
    }

    @discardableResult
    func activate(options _: NSApplication.ActivationOptions) -> Bool {
        activateCallCount += 1
        return activateResult
    }

    @discardableResult
    func terminate() -> Bool {
        terminateCallCount += 1
        return terminateResult
    }

    @discardableResult
    func hide() -> Bool {
        hideCallCount += 1
        return hideResult
    }
}
