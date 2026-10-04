import AppKit
import ApplicationServices
import dawnLogging

struct FocusedWindowFrame: Equatable, Sendable {
    let pid: pid_t
    let frame: CGRect
}

@MainActor
protocol FocusWindowTracking {
    var onFocusedFrameChange: ((FocusedWindowFrame?) -> Void)? { get set }

    func start()
    func stop()
}

@MainActor
final class FocusWindowTracker: FocusWindowTracking {
    var onFocusedFrameChange: ((FocusedWindowFrame?) -> Void)?

    private let workspace: NSWorkspace
    private let ownPID: pid_t

    private var activateObserver: NSObjectProtocol?
    private var axObserver: AXObserver?
    private var observedAppElement: AXUIElement?
    private var observedWindowElement: AXUIElement?
    private var observedPID: pid_t?
    private var isRunning = false

    init(
        workspace: NSWorkspace = .shared,
        ownPID: pid_t = ProcessInfo.processInfo.processIdentifier
    ) {
        self.workspace = workspace
        self.ownPID = ownPID
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true

        guard ensureAccessibilityTrusted(prompt: shouldPromptForAccessibility) else {
            #log(
                "Focus border tracker inactive: Accessibility not trusted",
                level: .warning,
                category: .general
            )
            onFocusedFrameChange?(nil)
            return
        }

        activateObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleFrontmostApplicationChanged()
            }
        }

        handleFrontmostApplicationChanged()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false

        if let activateObserver {
            workspace.notificationCenter.removeObserver(activateObserver)
            self.activateObserver = nil
        }

        tearDownAXObserver()
        onFocusedFrameChange?(nil)
    }

    private var shouldPromptForAccessibility: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
    }

    private func ensureAccessibilityTrusted(prompt: Bool) -> Bool {
        if AXIsProcessTrusted() {
            return true
        }

        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func handleFrontmostApplicationChanged() {
        guard isRunning else { return }

        guard let app = workspace.frontmostApplication else {
            publish(nil)
            tearDownAXObserver()
            return
        }

        if app.processIdentifier == ownPID {
            publish(nil)
            tearDownAXObserver()
            return
        }

        observe(application: app)
        publish(focusedWindowFrame(for: app))
    }

    private func observe(application app: NSRunningApplication) {
        let pid = app.processIdentifier
        if observedPID == pid, axObserver != nil {
            refreshObservedWindow()
            return
        }

        tearDownAXObserver()

        var observer: AXObserver?
        let createResult = AXObserverCreate(pid, axObserverCallback, &observer)
        guard createResult == .success, let observer else {
            #log(
                "Failed to create AXObserver for pid \(pid): \(createResult.rawValue)",
                level: .error,
                category: .general
            )
            return
        }

        let appElement = AXUIElementCreateApplication(pid)
        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        let appNotifications = [
            kAXFocusedWindowChangedNotification,
            kAXMainWindowChangedNotification,
            kAXApplicationHiddenNotification,
        ]

        for notification in appNotifications {
            let addResult = AXObserverAddNotification(
                observer,
                appElement,
                notification as CFString,
                refcon
            )
            if addResult != .success, addResult != .notificationAlreadyRegistered {
                #log(
                    "Failed to observe \(notification) for pid \(pid): \(addResult.rawValue)",
                    level: .warning,
                    category: .general
                )
            }
        }

        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .commonModes
        )

        axObserver = observer
        observedAppElement = appElement
        observedPID = pid
        refreshObservedWindow()
    }

    private func refreshObservedWindow() {
        guard let observer = axObserver, let appElement = observedAppElement else { return }

        if let previousWindow = observedWindowElement {
            AXObserverRemoveNotification(
                observer,
                previousWindow,
                kAXWindowMovedNotification as CFString
            )
            AXObserverRemoveNotification(
                observer,
                previousWindow,
                kAXWindowResizedNotification as CFString
            )
            observedWindowElement = nil
        }

        guard let window = focusedWindowElement(in: appElement) else { return }

        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        for notification in [kAXWindowMovedNotification, kAXWindowResizedNotification] {
            let addResult = AXObserverAddNotification(
                observer,
                window,
                notification as CFString,
                refcon
            )
            if addResult != .success, addResult != .notificationAlreadyRegistered {
                #log(
                    "Failed to observe \(notification): \(addResult.rawValue)",
                    level: .warning,
                    category: .general
                )
            }
        }

        observedWindowElement = window
    }

    private func tearDownAXObserver() {
        if let observer = axObserver {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(observer),
                .commonModes
            )
        }

        axObserver = nil
        observedAppElement = nil
        observedWindowElement = nil
        observedPID = nil
    }

    fileprivate func handleAXNotification() {
        guard isRunning else { return }

        guard let app = workspace.frontmostApplication,
              app.processIdentifier != ownPID
        else {
            publish(nil)
            return
        }

        refreshObservedWindow()
        publish(focusedWindowFrame(for: app))
    }

    private func publish(_ frame: FocusedWindowFrame?) {
        onFocusedFrameChange?(frame)
    }

    private func focusedWindowFrame(for app: NSRunningApplication) -> FocusedWindowFrame? {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        guard let window = focusedWindowElement(in: appElement),
              isWindowElement(window),
              !isMinimized(window),
              let axRect = axFrame(of: window)
        else {
            return nil
        }

        let cocoaRect = Self.appKitRect(
            fromAccessibility: axRect,
            primaryScreenFrame: NSScreen.screens.first?.frame
        )
        guard Self.isDisplayableWindowFrame(cocoaRect) else { return nil }

        return FocusedWindowFrame(pid: app.processIdentifier, frame: cocoaRect)
    }

    private func focusedWindowElement(in appElement: AXUIElement) -> AXUIElement? {
        copyElementAttribute(appElement, kAXFocusedWindowAttribute)
    }

    private func isWindowElement(_ element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXRoleAttribute as CFString,
            &value
        ) == .success,
            let role = value as? String
        else {
            return false
        }
        return role == kAXWindowRole
    }

    private func isMinimized(_ element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXMinimizedAttribute as CFString,
            &value
        ) == .success,
            let value
        else {
            return false
        }

        if let minimized = value as? Bool {
            return minimized
        }
        if CFGetTypeID(value) == CFBooleanGetTypeID() {
            return CFBooleanGetValue((value as! CFBoolean))
        }
        return false
    }

    private func copyElementAttribute(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }
        return (value as! AXUIElement)
    }

    private func axFrame(of element: AXUIElement) -> CGRect? {
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, "AXFrame" as CFString, &value) == .success,
           let rect = cgRect(from: value)
        {
            return rect
        }

        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXPositionAttribute as CFString,
            &positionValue
        ) == .success,
            AXUIElementCopyAttributeValue(
                element,
                kAXSizeAttribute as CFString,
                &sizeValue
            ) == .success,
            let origin = cgPoint(from: positionValue),
            let size = cgSize(from: sizeValue)
        else {
            return nil
        }

        return CGRect(origin: origin, size: size)
    }

    private func cgRect(from value: CFTypeRef?) -> CGRect? {
        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(value as! AXValue, .cgRect, &rect) else { return nil }
        return rect
    }

    private func cgPoint(from value: CFTypeRef?) -> CGPoint? {
        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(value as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    private func cgSize(from value: CFTypeRef?) -> CGSize? {
        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(value as! AXValue, .cgSize, &size) else { return nil }
        return size
    }

    static let minimumWindowDimension: CGFloat = 50

    static func isDisplayableWindowFrame(_ rect: CGRect) -> Bool {
        rect.width.isFinite
            && rect.height.isFinite
            && rect.width >= minimumWindowDimension
            && rect.height >= minimumWindowDimension
    }

    static func appKitRect(
        fromAccessibility rect: CGRect,
        primaryScreenFrame: CGRect?
    ) -> CGRect {
        guard let primaryScreenFrame else { return rect }
        return CGRect(
            x: rect.origin.x,
            y: primaryScreenFrame.maxY - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }
}

private func axObserverCallback(
    _: AXObserver,
    _: AXUIElement,
    _: CFString,
    refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    let tracker = Unmanaged<FocusWindowTracker>.fromOpaque(refcon).takeUnretainedValue()
    Task { @MainActor in
        tracker.handleAXNotification()
    }
}
