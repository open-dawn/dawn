import AppKit
import dawnLogging
import Foundation
import libdawn

struct WMWindowLayoutAction: WMAppAction {
    private(set) var app: WorkspaceApplication
    private let provider: ApplicationProvider
    private let windows: any AccessibilityWindowServing
    private let trustChecker: any AccessibilityTrustChecking

    func execute() async throws(WMActionError) {
        guard trustChecker.isProcessTrusted() else {
            #log(
                "Skipping window layout for \(app.bundleIdentifier): Accessibility not trusted",
                level: .error,
                category: .general
            )
            throw .accessibilityNotTrusted
        }

        guard let runningApp = provider.runningApplications(withBundleIdentifier: app.bundleIdentifier).first
        else {
            throw .notRunning
        }

        let targetWindows: [AccessibilityWindow]
        do {
            targetWindows = try windows.windows(forProcessID: runningApp.processIdentifier)
        } catch {
            throw map(accessibilityError: error)
        }

        guard !targetWindows.isEmpty else {
            throw .noGUItoShow
        }

        for window in targetWindows {
            try applyMapped(app.windowLayout, to: window)
        }
    }

    private func applyMapped(
        _ layout: WorkspaceWindowLayout,
        to window: AccessibilityWindow
    ) throws(WMActionError) {
        do {
            try apply(layout, to: window)
        } catch let error as AccessibilityError {
            throw map(accessibilityError: error)
        } catch {
            throw .unknown(reason: error.localizedDescription)
        }
    }

    private func apply(
        _ layout: WorkspaceWindowLayout,
        to window: AccessibilityWindow
    ) throws(AccessibilityError) {
        switch layout {
        case .window:
            try setFullscreenBestEffort(window, fullscreen: false)
            try windows.setMinimized(window, minimized: false)
            try windows.raise(window)

        case .minimized:
            try setFullscreenBestEffort(window, fullscreen: false)
            try windows.setMinimized(window, minimized: true)

        case .fullscreen:
            try windows.setMinimized(window, minimized: false)
            try windows.setFullscreen(window, fullscreen: true)
            try windows.raise(window)
        }
    }

    private func setFullscreenBestEffort(
        _ window: AccessibilityWindow,
        fullscreen: Bool
    ) throws(AccessibilityError) {
        do {
            try windows.setFullscreen(window, fullscreen: fullscreen)
        } catch let error as AccessibilityError {
            if case .attributeUnavailable = error, !fullscreen {
                return
            }
            throw error
        }
    }

    private func map(accessibilityError error: Error) -> WMActionError {
        guard let axError = error as? AccessibilityError else {
            return .unknown(reason: error.localizedDescription)
        }

        return switch axError {
        case .notTrusted:
            .accessibilityNotTrusted
        case let .attributeUnavailable(name):
            .unknown(reason: "Unsupported Accessibility attribute: \(name)")
        case let .unexpectedValue(name):
            .unknown(reason: "Unexpected Accessibility value: \(name)")
        case let .axFailure(code):
            .unknown(reason: "Accessibility failure (\(code))")
        }
    }

    init(
        app: WorkspaceApplication,
        provider: ApplicationProvider = SystemApplicationProvider(),
        windows: any AccessibilityWindowServing = SystemAccessibilityWindowService(),
        trustChecker: any AccessibilityTrustChecking = SystemAccessibilityTrustChecker()
    ) {
        self.app = app
        self.provider = provider
        self.windows = windows
        self.trustChecker = trustChecker
    }
}
