import AppKit
import Foundation
import PaEventKit
@testable import PaWM
import Testing

@Suite("WMCloseAppAction Testing")
struct WMCloseAppActionTests {
    @Test("throws notRunning if app is closed")
    func notRunningError() {
        let mockApp = WorkspaceApplication(bundleIdentifier: "", displayName: "", applicationURL: nil)
        let fakeAppProvider = FakeAppProvider()
        fakeAppProvider.apps = []

        let action = WMCloseAppAction(mockApp, provider: fakeAppProvider)
        #expect(throws: WMActionError.notRunning) {
            try action.execute()
        }
    }

    @Test("success closes an app")
    func successClose() throws {
        let mockApp = WorkspaceApplication(bundleIdentifier: "com.apple.Safari",
                                           displayName: "Safari",
                                           applicationURL: URL(filePath: "Applications/Safari.app"))
        let mockRunningApp = FakeRunningApp()
        mockRunningApp.terminateResult = true

        let mockAppProvider = FakeAppProvider()
        mockAppProvider.apps = [mockRunningApp]

        let action = WMCloseAppAction(mockApp, provider: mockAppProvider)
        #expect(throws: Never.self) { try action.execute() }
    }

    @Test("throws permissionDenied if cant closes an app")
    func permissionDeniedError() throws {
        let mockApp = WorkspaceApplication(bundleIdentifier: "com.apple.Safari",
                                           displayName: "Safari",
                                           applicationURL: URL(filePath: "Applications/Safari.app"))
        let mockRunningApp = FakeRunningApp()
        mockRunningApp.terminateResult = false

        let mockAppProvider = FakeAppProvider()
        mockAppProvider.apps = [mockRunningApp]

        let action = WMCloseAppAction(mockApp, provider: mockAppProvider)
        #expect(throws: WMActionError.permissionDenied) { try action.execute() }
    }
}
