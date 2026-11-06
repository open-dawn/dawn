import AppKit
import Foundation
import libdawn
@testable import dawnAgent
import Testing

@Suite("WMHideAppAction Testing")
struct WMHideAppActionTests {
    @Test("throws notRunning if app is closed")
    func notRunningError() async {
        let mockApp = WorkspaceApplication(bundleIdentifier: "", displayName: "", applicationURL: nil)
        let fakeAppProvider = FakeAppProvider()

        let action = WMHideAppAction(app: mockApp, provider: fakeAppProvider)
        await #expect(throws: WMActionError.notRunning) {
            try await action.execute()
        }
    }

    @Test("success hides an app")
    func successClose() async throws {
        let mockApp = WorkspaceApplication(bundleIdentifier: "com.apple.Safari",
                                           displayName: "Safari",
                                           applicationURL: URL(filePath: "Applications/Safari.app"))
        let mockRunningApp = FakeRunningApp(bundleIdentifier: "com.apple.Safari")
        mockRunningApp.hideResult = true

        let mockAppProvider = FakeAppProvider()
        mockAppProvider.appsByBundleIdentifier = ["com.apple.Safari": [mockRunningApp]]

        let action = WMHideAppAction(app: mockApp, provider: mockAppProvider)
        await #expect(throws: Never.self) { try await action.execute() }
    }

    @Test("throws noGuiToShow if cant hides an app")
    func noGuiError() async throws {
        let mockApp = WorkspaceApplication(bundleIdentifier: "com.apple.Safari",
                                           displayName: "Safari",
                                           applicationURL: URL(filePath: "Applications/Safari.app"))
        let mockRunningApp = FakeRunningApp(bundleIdentifier: "com.apple.Safari")
        mockRunningApp.hideResult = false

        let mockAppProvider = FakeAppProvider()
        mockAppProvider.appsByBundleIdentifier = ["com.apple.Safari": [mockRunningApp]]

        let action = WMHideAppAction(app: mockApp, provider: mockAppProvider)
        await #expect(throws: WMActionError.noGUItoShow) { try await action.execute() }
    }
}
