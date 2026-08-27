import AppKit
import Foundation
import PaEventKit
@testable import PaWM
import Testing

@Suite("WMOpenAppAction Testing")
struct WMOpenAppActionTests {
    @Test("throws invalidURL if app has nil URL")
    func nullFilePathError() async {
        let mockApp = WorkspaceApplication(bundleIdentifier: "", displayName: "", applicationURL: nil)
        let fakeWorkspace = FakeWorkspace()

        let action = WMOpenAppAction(mockApp, workspace: fakeWorkspace)

        await #expect(throws: WMActionError.invalidURL) {
            try await action.execute()
        }
    }

    @Test("throws notFound with filepath does not exist")
    func invalidPathError() async throws {
        let mockApp = WorkspaceApplication(bundleIdentifier: "",
                                           displayName: "",
                                           applicationURL: URL(filePath: ".invalid_file.swift"))
        let fakeWorkspace = FakeWorkspace()
        fakeWorkspace.errorToThrow = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError, userInfo: [:])

        let action = WMOpenAppAction(mockApp, workspace: fakeWorkspace)

        let appURL = try #require(mockApp.applicationURL)
        await #expect(throws: WMActionError.notFound(filePath: appURL.path())) {
            try await action.execute()
        }
    }

    @Test("throws CorruptedFile with corrupted file")
    func corruptedFileError() async throws {
        let mockApp = WorkspaceApplication(bundleIdentifier: "",
                                           displayName: "",
                                           applicationURL: URL(filePath: ".corrupted_file.swift"))
        let fakeWorkspace = FakeWorkspace()
        fakeWorkspace.errorToThrow = NSError(domain: NSCocoaErrorDomain,
                                             code: NSFileReadCorruptFileError,
                                             userInfo: [:])

        let action = WMOpenAppAction(mockApp, workspace: fakeWorkspace)

        try #require(mockApp.applicationURL != nil)
        await #expect(throws: WMActionError.corruptedFile) {
            try await action.execute()
        }
    }

    @Test("throws PermissionDenied with root file")
    func permissionDeniedError() async throws {
        let mockApp = WorkspaceApplication(bundleIdentifier: "",
                                           displayName: "",
                                           applicationURL: URL(filePath: ".root.swift"))
        let fakeWorkspace = FakeWorkspace()
        fakeWorkspace.errorToThrow = NSError(domain: NSCocoaErrorDomain,
                                             code: NSFileReadNoPermissionError,
                                             userInfo: [:])

        let action = WMOpenAppAction(mockApp, workspace: fakeWorkspace)

        try #require(mockApp.applicationURL != nil)
        await #expect(throws: WMActionError.permissionDenied) {
            try await action.execute()
        }
    }

    @Test("throws unknown with no mapped error")
    func unknownError() async throws {
        let mockApp = WorkspaceApplication(bundleIdentifier: "",
                                           displayName: "",
                                           applicationURL: URL(filePath: "???.swift"))
        let fakeWorkspace = FakeWorkspace()
        fakeWorkspace.errorToThrow = NSError(domain: "idkw", code: 5, userInfo: [:])

        let action = WMOpenAppAction(mockApp, workspace: fakeWorkspace)

        try #require(mockApp.applicationURL != nil)
        let errorMessage = fakeWorkspace.errorToThrow?.localizedDescription
        await #expect(throws: WMActionError.unknown(reason: errorMessage)) {
            try await action.execute()
        }
    }

    @Test("success open an app")
    func validPathOpen() async throws {
        let mockApp = WorkspaceApplication(bundleIdentifier: "com.apple.Safari",
                                           displayName: "Safari",
                                           applicationURL: URL(filePath: "Applications/Safari.app"))
        let fakeWorkspace = FakeWorkspace()
        let action = WMOpenAppAction(mockApp, workspace: fakeWorkspace)

        try #require(mockApp.applicationURL != nil)
        await #expect(throws: Never.self) { try await action.execute() }
    }
}

final class FakeWorkspace: WorkspaceOpener {
    var didCallOpenApplication: Bool = false
    var errorToThrow: Error?

    func openApplication(at _: URL,
                         configuration _: NSWorkspace.OpenConfiguration) async throws -> NSRunningApplication
    {
        didCallOpenApplication = true
        if let error = errorToThrow {
            throw error
        }

        return NSRunningApplication()
    }
}
