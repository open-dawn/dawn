@testable import dawnAgent

final class FakeAccessibilityTrustChecker: AccessibilityTrustChecking, @unchecked Sendable {
    var isTrusted = false
    var promptResult = false
    private(set) var didPrompt = false

    func isProcessTrusted() -> Bool {
        isTrusted
    }

    @discardableResult
    func promptForTrust() -> Bool {
        didPrompt = true
        isTrusted = promptResult
        return promptResult
    }
}
