import AppKit
import Foundation
import PaEventKit
@testable import PaWM
import Testing

@Suite("WMHideAppAction Testing")
struct WMHideAppActionTests {
    @Test("throws notRunning if app is closed")
    func notRunningError() async {
        let mockApp = WorkspaceApplication(bundleIdentifier: "", displayName: "", applicationURL: nil)
        let fakeAppProvider = FakeAppProvider()
        fakeAppProvider.apps = []

        let action = WMHideAppAction(mockApp, provider: fakeAppProvider)
        await #expect(throws: WMActionError.notRunning) {
            try await action.execute()
        }
    }

    @Test("success hides an app")
    func successClose() async throws {
        let mockApp = WorkspaceApplication(bundleIdentifier: "com.apple.Safari",
                                           displayName: "Safari",
                                           applicationURL: URL(filePath: "Applications/Safari.app"))
        let mockRunningApp = FakeRunningApp()
        mockRunningApp.hideResult = true

        let mockAppProvider = FakeAppProvider()
        mockAppProvider.apps = [mockRunningApp]

        let action = WMHideAppAction(mockApp, provider: mockAppProvider)
        await #expect(throws: Never.self) { try await action.execute() }
    }

    @Test("throws permissionDenied if cant hides an app")
    func permissionDeniedError() async throws {
        let mockApp = WorkspaceApplication(bundleIdentifier: "com.apple.Safari",
                                           displayName: "Safari",
                                           applicationURL: URL(filePath: "Applications/Safari.app"))
        let mockRunningApp = FakeRunningApp()
        mockRunningApp.hideResult = false

        let mockAppProvider = FakeAppProvider()
        mockAppProvider.apps = [mockRunningApp]

        let action = WMHideAppAction(mockApp, provider: mockAppProvider)
        await #expect(throws: WMActionError.noGUItoShow) { try await action.execute() }
    }
}
