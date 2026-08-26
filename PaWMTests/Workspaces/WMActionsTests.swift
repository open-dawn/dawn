import Foundation
import PaEventKit
@testable import PaWM
import Testing

struct WMActionsTests {
    @Test("WMActionOpenApp with nil URL throws InvalidURL")
    func nullPathOpen() async {
        let app = WorkspaceApplication(bundleIdentifier: "", displayName: "", applicationURL: nil)
        let action = WMAOpenApp(app)
        await #expect(throws: WMActionError.invalidURL) {
            try await action.execute()
        }
    }

    @Test("WMActionOpenApp with non-existent file throw NotFound")
    func invalidPathOpen() async throws {
        let app = WorkspaceApplication(bundleIdentifier: "", displayName: "", applicationURL: URL(filePath: "/error-wm"))
        let action = WMAOpenApp(app)

        let appURL = try #require(app.applicationURL)
        await #expect(throws: WMActionError.notFound(filePath: appURL.path())) {
            try await action.execute()
        }
    }

    @Test("WMActionHideApp throw error if app is closed")
    func hideAppClosed() async throws {
        let app = WorkspaceApplication(bundleIdentifier: "com.apple.safari",
                                       displayName: "Safari",
                                       applicationURL: URL(filePath: "Applications/Safari.app"))
        let action = WMAHideApp(app)
        try #require(app.applicationURL != nil)
        await #expect(throws: WMActionError.notRunning) {
            try await action.execute()
        }
    }

    @Test("WMActionOpenApp open an app with valid filepath")
    func validPathOpen() async throws {
        let app = WorkspaceApplication(bundleIdentifier: "com.apple.safari",
                                       displayName: "Safari",
                                       applicationURL: URL(filePath: "Applications/Safari.app"))
        let action = WMAOpenApp(app)
        try #require(app.applicationURL != nil)

        await #expect(throws: Never.self) { try await action.execute() }
    }

    @Test("WMActionHideApp hides an valid and running app")
    func validAppHides() async throws {
        let app = WorkspaceApplication(bundleIdentifier: "com.apple.safari",
                                       displayName: "Safari",
                                       applicationURL: URL(filePath: "Applications/Safari.app"))
        let action = WMAOpenApp(app)
        try #require(app.applicationURL != nil)
        await #expect(throws: Never.self) { try await action.execute() }
    }
}
