import AppKit
@testable import dawnAgent

final class FakeRunningApp: RunningApplicationControlling {
    var processIdentifier: pid_t = 1234
    var bundleIdentifier: String?
    var activationPolicy: NSApplication.ActivationPolicy = .regular
    var isHidden = false
    var activateResult = true
    var terminateResult = true
    var hideResult = true
    var unhideResult = true

    private(set) var didActivate = false
    private(set) var didUnhide = false
    private(set) var lastActivationOptions: NSApplication.ActivationOptions?

    private(set) var activateCallCount = 0
    private(set) var terminateCallCount = 0
    private(set) var hideCallCount = 0

    init(bundleIdentifier: String? = nil, processIdentifier: pid_t = 1234) {
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
    }

    @discardableResult
    func activate(options: NSApplication.ActivationOptions) -> Bool {
        activateCallCount += 1
        didActivate = true
        lastActivationOptions = options
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

    @discardableResult
    func unhide() -> Bool {
        didUnhide = true
        if unhideResult {
            isHidden = false
        }
        return unhideResult
    }
}
