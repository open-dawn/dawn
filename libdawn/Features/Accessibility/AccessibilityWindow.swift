import Foundation

public final class AccessibilityWindow {
    public let processID: pid_t
    public let title: String?
    public let element: any AccessibilityElementServing

    public init(
        processID: pid_t,
        title: String?,
        element: any AccessibilityElementServing
    ) {
        self.processID = processID
        self.title = title
        self.element = element
    }
}

public protocol AccessibilityWindowServing: AnyObject {
    func windows(forProcessID processID: pid_t) throws(AccessibilityError) -> [AccessibilityWindow]
    func raise(_ window: AccessibilityWindow) throws(AccessibilityError)

    func setMinimized(_ window: AccessibilityWindow, minimized: Bool) throws(AccessibilityError)
    func isMinimized(_ window: AccessibilityWindow) throws(AccessibilityError) -> Bool

    func isFullscreen(_ window: AccessibilityWindow) throws(AccessibilityError) -> Bool?
    func setFullscreen(_ window: AccessibilityWindow, fullscreen: Bool) throws(AccessibilityError)
}
