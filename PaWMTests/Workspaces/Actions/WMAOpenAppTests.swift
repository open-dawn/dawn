import AppKit
import Foundation
import PaEventKit
@testable import PaWM
import Testing

struct WMAOpenAppTests {
    @Test("throws invalidURL if app has nil URL")
    func nullPathOpen() async {
        let mockApp = WorkspaceApplication(bundleIdentifier: "", displayName: "", applicationURL: nil)
        let fakeWorkspace = FakeWorkspace()
        let fakeFileManager = FakeFileManager()

        let action = WMAOpenApp(mockApp, workspace: fakeWorkspace, fileManager: fakeFileManager)

        await #expect(throws: WMActionError.invalidURL) {
            try await action.execute()
        }
    }

    @Test("throws notFound with filepath does not exist")
    func invalidPathOpen() async throws {
        let mockApp = WorkspaceApplication(bundleIdentifier: "",
                                           displayName: "",
                                           applicationURL: URL(filePath: ".invalid_file.swift"))
        let fakeWorkspace = FakeWorkspace()
        let fakeFileManager = FakeFileManager()
        fakeFileManager.shouldReturnExists = false

        let action = WMAOpenApp(mockApp, workspace: fakeWorkspace, fileManager: fakeFileManager)

        let appURL = try #require(mockApp.applicationURL)
        await #expect(throws: WMActionError.notFound(filePath: appURL.path())) {
            try await action.execute()
        }
    }

    // @Test("")
    // func permissionDenied() {}

    // @Test("")
    // func corruptedFile() {}
    //
    // @Test("")
    // func unknownErrorOpenApp() {}

    @Test("WMAOpenApp success open an app")
    func validPathOpen() async throws {
        let mockApp = WorkspaceApplication(bundleIdentifier: "com.apple.Safari",
                                           displayName: "Safari",
                                           applicationURL: URL(filePath: "Applications/Safari.app"))
        let fakeWorkspace = FakeWorkspace()
        let fakeFileManager = FakeFileManager()
        let action = WMAOpenApp(mockApp, workspace: fakeWorkspace, fileManager: fakeFileManager)

        try #require(mockApp.applicationURL != nil)
        await #expect(throws: Never.self) { try await action.execute() }
    }
}

final class FakeWorkspace: WorkspaceOpener {
    var didCallOpenApplication: Bool = false
    var urlPassed: URL?
    var errorToThrow: Error?

    func openApplication(at url: URL,
                         configuration _: NSWorkspace.OpenConfiguration) async throws -> NSRunningApplication
    {
        didCallOpenApplication = true
        urlPassed = url
        if let error = errorToThrow {
            throw error
        }

        return NSRunningApplication()
    }
}

final class FakeFileManager: FileChecker {
    var shouldReturnExists: Bool = true

    func fileExists(atPath _: String) -> Bool {
        return shouldReturnExists
    }
}
