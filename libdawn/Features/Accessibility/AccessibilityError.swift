import ApplicationServices
import Foundation

public enum AccessibilityError: Error, Equatable, LocalizedError {
    case notTrusted
    case attributeUnavailable(String)
    case unexpectedValue(String)
    case axFailure(code: Int32)

    public var errorDescription: String? {
        switch self {
        case .notTrusted: "Accessibility permission is required"
        case let .attributeUnavailable(name): "Accessibility attribute unavailable: \(name)"
        case let .unexpectedValue(name): "Unexpected Accessibility value for: \(name)"
        case let .axFailure(code): "Accessibility API failure (AXError \(code))"
        }
    }

    public static func from(_ error: AXError, attribute: String? = nil) -> AccessibilityError {
        switch error {
        case .success: .axFailure(code: error.rawValue)
        case .apiDisabled, .cannotComplete: .notTrusted
        case .attributeUnsupported, .actionUnsupported, .noValue, .invalidUIElement:
            .attributeUnavailable(attribute ?? "unknown")
        default:
            .axFailure(code: error.rawValue)
        }
    }
}
