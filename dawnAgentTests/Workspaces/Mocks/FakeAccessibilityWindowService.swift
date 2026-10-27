import Foundation
import libdawn
@testable import dawnAgent

@MainActor
final class FakeAccessibilityElement: AccessibilityElementServing {
    func attributeValue(for _: AccessibilityAttribute) throws(AccessibilityError) -> Any? { nil }

    func setAttributeValue(_: Any, for _: AccessibilityAttribute) throws(AccessibilityError) {}

    func performAction(_: AccessibilityAction) throws(AccessibilityError) {}
}

@MainActor
final class FakeAccessibilityWindowService: AccessibilityWindowServing {
    var windowsByPID: [pid_t: [AccessibilityWindow]] = [:]
    var windowsError: AccessibilityError?

    private(set) var raised: [AccessibilityWindow] = []
    private(set) var minimizedStates: [(AccessibilityWindow, Bool)] = []
    private(set) var fullscreenStates: [(AccessibilityWindow, Bool)] = []

    func windows(forProcessID processID: pid_t) throws(AccessibilityError) -> [AccessibilityWindow] {
        if let windowsError {
            throw windowsError
        }
        return windowsByPID[processID] ?? []
    }

    func raise(_ window: AccessibilityWindow) throws(AccessibilityError) {
        raised.append(window)
    }

    func setMinimized(_ window: AccessibilityWindow, minimized: Bool) throws(AccessibilityError) {
        minimizedStates.append((window, minimized))
    }

    func isMinimized(_: AccessibilityWindow) throws(AccessibilityError) -> Bool {
        false
    }

    func isFullscreen(_: AccessibilityWindow) throws(AccessibilityError) -> Bool? {
        nil
    }

    func setFullscreen(_ window: AccessibilityWindow, fullscreen: Bool) throws(AccessibilityError) {
        fullscreenStates.append((window, fullscreen))
    }
}
