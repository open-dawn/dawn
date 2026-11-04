import Foundation

public enum AccessibilityAttribute: String, Sendable {
    case windows = "AXWindows"
    case title = "AXTitle"
    case minimized = "AXMinimized"
    case fullScreen = "AXFullScreen"
    case frontmost = "AXFrontmost"
}

public enum AccessibilityAction: String, Sendable {
    case raise = "AXRaise"
}
