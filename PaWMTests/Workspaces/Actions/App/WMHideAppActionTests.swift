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
        fakeAppProvider.shouldFail = true

        let action = WMHideAppAction(mockApp, provider: fakeAppProvider)
        await #expect(throws: WMActionError.notRunning) {
            try await action.execute()
        }
    }

    @Test("success open an app")
    func validPathOpen() async throws {
        let mockApp = WorkspaceApplication(bundleIdentifier: "com.apple.Safari",
                                           displayName: "Safari",
                                           applicationURL: URL(filePath: "Applications/Safari.app"))
        let fakeAppProvider = FakeAppProvider()
        let action = WMHideAppAction(mockApp, provider: fakeAppProvider)

        await #expect(throws: Never.self) { try await action.execute() }
    }
}
