import Foundation
import libdawn
@testable import dawnAgent
import Testing

@MainActor
@Suite("WMWindowLayoutAction Testing")
struct WMWindowLayoutActionTests {
    @Test("throws accessibilityNotTrusted when AX is not trusted")
    func notTrusted() async {
        let app = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            windowLayout: .minimized
        )
        let trust = FakeAccessibilityTrustChecker()
        trust.isTrusted = false

        let action = WMWindowLayoutAction(
            app: app,
            provider: FakeAppProvider(),
            windows: FakeAccessibilityWindowService(),
            trustChecker: trust
        )

        await #expect(throws: WMActionError.accessibilityNotTrusted) {
            try await action.execute()
        }
    }

    @Test("throws notRunning when app process is missing")
    func notRunning() async {
        let app = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            windowLayout: .window
        )
        let provider = FakeAppProvider()
        let trust = FakeAccessibilityTrustChecker()
        trust.isTrusted = true

        let action = WMWindowLayoutAction(
            app: app,
            provider: provider,
            windows: FakeAccessibilityWindowService(),
            trustChecker: trust
        )

        await #expect(throws: WMActionError.notRunning) {
            try await action.execute()
        }
    }

    @Test("throws noGUItoShow when running app has no windows")
    func noWindows() async {
        let app = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            windowLayout: .window
        )
        let running = FakeRunningApp(bundleIdentifier: app.bundleIdentifier, processIdentifier: 42)
        let provider = FakeAppProvider()
        provider.appsByBundleIdentifier[app.bundleIdentifier] = [running]

        let windows = FakeAccessibilityWindowService()
        windows.windowsByPID[42] = []

        let trust = FakeAccessibilityTrustChecker()
        trust.isTrusted = true

        let action = WMWindowLayoutAction(
            app: app,
            provider: provider,
            windows: windows,
            trustChecker: trust
        )

        await #expect(throws: WMActionError.noGUItoShow) {
            try await action.execute()
        }
    }

    @Test("applies minimized layout to all windows")
    func appliesMinimized() async throws {
        let app = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            windowLayout: .minimized
        )
        let running = FakeRunningApp(bundleIdentifier: app.bundleIdentifier, processIdentifier: 7)
        let provider = FakeAppProvider()
        provider.appsByBundleIdentifier[app.bundleIdentifier] = [running]

        let window = AccessibilityWindow(
            processID: 7,
            title: "Safari",
            element: FakeAccessibilityElement()
        )
        let windows = FakeAccessibilityWindowService()
        windows.windowsByPID[7] = [window]

        let trust = FakeAccessibilityTrustChecker()
        trust.isTrusted = true

        let action = WMWindowLayoutAction(
            app: app,
            provider: provider,
            windows: windows,
            trustChecker: trust
        )

        try await action.execute()

        #expect(windows.fullscreenStates.map(\.1) == [false])
        #expect(windows.minimizedStates.map(\.1) == [true])
        #expect(windows.raised.isEmpty)
    }

    @Test("applies window layout by clearing minimize/fullscreen and raising")
    func appliesWindowLayout() async throws {
        let app = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            windowLayout: .window
        )
        let running = FakeRunningApp(bundleIdentifier: app.bundleIdentifier, processIdentifier: 9)
        let provider = FakeAppProvider()
        provider.appsByBundleIdentifier[app.bundleIdentifier] = [running]

        let window = AccessibilityWindow(
            processID: 9,
            title: "Safari",
            element: FakeAccessibilityElement()
        )
        let windows = FakeAccessibilityWindowService()
        windows.windowsByPID[9] = [window]

        let trust = FakeAccessibilityTrustChecker()
        trust.isTrusted = true

        let action = WMWindowLayoutAction(
            app: app,
            provider: provider,
            windows: windows,
            trustChecker: trust
        )

        try await action.execute()

        #expect(windows.fullscreenStates.map(\.1) == [false])
        #expect(windows.minimizedStates.map(\.1) == [false])
        #expect(windows.raised.count == 1)
    }

    @Test("applies fullscreen layout")
    func appliesFullscreen() async throws {
        let app = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            windowLayout: .fullscreen
        )
        let running = FakeRunningApp(bundleIdentifier: app.bundleIdentifier, processIdentifier: 11)
        let provider = FakeAppProvider()
        provider.appsByBundleIdentifier[app.bundleIdentifier] = [running]

        let window = AccessibilityWindow(
            processID: 11,
            title: "Safari",
            element: FakeAccessibilityElement()
        )
        let windows = FakeAccessibilityWindowService()
        windows.windowsByPID[11] = [window]

        let trust = FakeAccessibilityTrustChecker()
        trust.isTrusted = true

        let action = WMWindowLayoutAction(
            app: app,
            provider: provider,
            windows: windows,
            trustChecker: trust
        )

        try await action.execute()

        #expect(windows.minimizedStates.map(\.1) == [false])
        #expect(windows.fullscreenStates.map(\.1) == [true])
        #expect(windows.raised.count == 1)
    }
}
