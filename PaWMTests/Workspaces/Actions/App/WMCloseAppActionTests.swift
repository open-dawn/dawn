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
        fakeAppProvider.shouldFail = true

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
        let fakeAppProvider = FakeAppProvider()
        let action = WMCloseAppAction(mockApp, provider: fakeAppProvider)

        #expect(throws: Never.self) { try action.execute() }
    }
}
