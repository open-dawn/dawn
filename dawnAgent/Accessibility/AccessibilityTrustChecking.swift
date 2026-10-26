import ApplicationServices
import Foundation

protocol AccessibilityTrustChecking: Sendable {
    func isProcessTrusted() -> Bool

    /// Shows the system Accessibility permission prompt when the process is not trusted.
    @discardableResult
    func promptForTrust() -> Bool
}

struct SystemAccessibilityTrustChecker: AccessibilityTrustChecking {
    func isProcessTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    func promptForTrust() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
