import ApplicationServices
import Foundation

protocol AccessibilityTrustChecking: Sendable {
    func isProcessTrusted() -> Bool
    func promptForTrust()
}

struct SystemAccessibilityTrustChecker: AccessibilityTrustChecking {
    func isProcessTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    func promptForTrust() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
