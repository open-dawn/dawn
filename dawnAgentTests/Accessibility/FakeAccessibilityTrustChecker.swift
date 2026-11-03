@testable import dawnAgent

final class FakeAccessibilityTrustChecker: AccessibilityTrustChecking, @unchecked Sendable {
    var isTrusted = false
    var promptResult: Bool?
    private(set) var didPrompt = false

    func isProcessTrusted() -> Bool {
        isTrusted
    }

    func promptForTrust() {
        didPrompt = true
        if let promptResult {
            isTrusted = promptResult
        }
    }
}
