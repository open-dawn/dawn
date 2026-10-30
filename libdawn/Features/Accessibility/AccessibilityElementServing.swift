import Foundation

public protocol AccessibilityElementServing: AnyObject {
    func attributeValue(for attribute: AccessibilityAttribute) throws(AccessibilityError) -> Any?
    func setAttributeValue(_ value: Any, for attribute: AccessibilityAttribute) throws(AccessibilityError)
    func performAction(_ action: AccessibilityAction) throws(AccessibilityError)
}

public protocol AccessibilityRuntimeServing: AnyObject {
    func applicationElement(processID: pid_t) -> any AccessibilityElementServing
    func element(wrapping raw: Any) throws(AccessibilityError) -> any AccessibilityElementServing
}
