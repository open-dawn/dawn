import ApplicationServices
import Foundation

public final class SystemAccessibilityElement: AccessibilityElementServing {
    private let element: AXUIElement

    public init(_ element: AXUIElement) {
        self.element = element
    }

    public convenience init(processID: pid_t) {
        self.init(AXUIElementCreateApplication(processID))
    }

    public var rawElement: AXUIElement {
        element
    }

    public func attributeValue(for attribute: AccessibilityAttribute) throws(AccessibilityError) -> Any? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute.rawValue as CFString, &value)

        switch result {
        case .success:
            guard let value else { return nil }
            if CFGetTypeID(value) == CFBooleanGetTypeID() {
                return CFEqual(value, kCFBooleanTrue)
            }
            return value as Any
        case .noValue:
            return nil
        default:
            throw AccessibilityError.from(result, attribute: attribute.rawValue)
        }
    }

    public func setAttributeValue(
        _ value: Any,
        for attribute: AccessibilityAttribute
    ) throws(AccessibilityError) {
        let cfValue: CFTypeRef
        if let boolValue = value as? Bool {
            cfValue = NSNumber(value: boolValue)
        } else {
            cfValue = value as CFTypeRef
        }

        let result = AXUIElementSetAttributeValue(
            element,
            attribute.rawValue as CFString,
            cfValue
        )

        guard result == .success else {
            throw AccessibilityError.from(result, attribute: attribute.rawValue)
        }
    }

    public func performAction(_ action: AccessibilityAction) throws(AccessibilityError) {
        let result = AXUIElementPerformAction(element, action.rawValue as CFString)

        guard result == .success else {
            throw AccessibilityError.from(result, attribute: action.rawValue)
        }
    }
}

public final class SystemAccessibilityRuntime: AccessibilityRuntimeServing {
    public init() {}

    public func applicationElement(processID: pid_t) -> any AccessibilityElementServing {
        SystemAccessibilityElement(processID: processID)
    }

    public func element(wrapping raw: Any) throws(AccessibilityError) -> any AccessibilityElementServing {
        let cfObject = raw as CFTypeRef
        guard CFGetTypeID(cfObject) == AXUIElementGetTypeID() else {
            throw .unexpectedValue("AXUIElement")
        }
        // `as? AXUIElement` always succeeds for CF types; type ID is the real check.
        let element = unsafeBitCast(cfObject, to: AXUIElement.self)
        return SystemAccessibilityElement(element)
    }
}
