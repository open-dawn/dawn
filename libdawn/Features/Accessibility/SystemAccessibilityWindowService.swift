import ApplicationServices
import Foundation

@MainActor
public final class SystemAccessibilityWindowService: AccessibilityWindowServing {
    private let runtime: any AccessibilityRuntimeServing

    public init(runtime: any AccessibilityRuntimeServing = SystemAccessibilityRuntime()) {
        self.runtime = runtime
    }

    public func windows(forProcessID processID: pid_t) throws(AccessibilityError) -> [AccessibilityWindow] {
        let application = runtime.applicationElement(processID: processID)
        guard let value = try application.attributeValue(for: AccessibilityAttribute.windows) else {
            return []
        }

        let rawWindows = try Self.axUIElements(from: value)
        var windows: [AccessibilityWindow] = []
        windows.reserveCapacity(rawWindows.count)

        for raw in rawWindows {
            let element = try runtime.element(wrapping: raw)
            let title = (try? element.attributeValue(for: AccessibilityAttribute.title)) as? String
            windows.append(
                AccessibilityWindow(
                    processID: processID,
                    title: title,
                    element: element
                )
            )
        }

        return windows
    }

    public func raise(_ window: AccessibilityWindow) throws(AccessibilityError) {
        if try isMinimized(window) {
            try setMinimized(window, minimized: false)
        }

        try window.element.performAction(AccessibilityAction.raise)

        let application = runtime.applicationElement(processID: window.processID)
        try application.setAttributeValue(true, for: AccessibilityAttribute.frontmost)
    }

    public func setMinimized(_ window: AccessibilityWindow, minimized: Bool) throws(AccessibilityError) {
        try window.element.setAttributeValue(
            minimized,
            for: AccessibilityAttribute.minimized
        )
    }

    public func isMinimized(_ window: AccessibilityWindow) throws(AccessibilityError) -> Bool {
        guard let value = try window.element.attributeValue(for: AccessibilityAttribute.minimized) else {
            return false
        }

        guard let minimized = value as? Bool else {
            throw .unexpectedValue(AccessibilityAttribute.minimized.rawValue)
        }

        return minimized
    }

    public func isFullscreen(_ window: AccessibilityWindow) throws(AccessibilityError) -> Bool? {
        do {
            guard let value = try window.element.attributeValue(for: AccessibilityAttribute.fullScreen) else {
                return nil
            }

            guard let fullscreen = value as? Bool else {
                throw AccessibilityError.unexpectedValue(AccessibilityAttribute.fullScreen.rawValue)
            }

            return fullscreen
        } catch let error as AccessibilityError {
            if case .attributeUnavailable = error {
                return nil
            }
            throw error
        } catch {
            throw AccessibilityError.unexpectedValue(error.localizedDescription)
        }
    }

    public func setFullscreen(_ window: AccessibilityWindow, fullscreen: Bool) throws(AccessibilityError) {
        try window.element.setAttributeValue(
            fullscreen,
            for: AccessibilityAttribute.fullScreen
        )
    }

    private static func axUIElements(from value: Any) throws(AccessibilityError) -> [AXUIElement] {
        if let elements = value as? [AXUIElement] {
            return elements
        }

        if let objects = value as? [AnyObject] {
            return try objects.map { object throws(AccessibilityError) in
                let cfObject = object as CFTypeRef
                guard CFGetTypeID(cfObject) == AXUIElementGetTypeID() else {
                    throw .unexpectedValue(AccessibilityAttribute.windows.rawValue)
                }
                return unsafeBitCast(cfObject, to: AXUIElement.self)
            }
        }

        throw .unexpectedValue(AccessibilityAttribute.windows.rawValue)
    }
}
