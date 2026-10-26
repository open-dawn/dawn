import AppKit
import Foundation
import libdawn
@testable import dawnAgent
import Testing

@Suite("WMOpenAppAction Testing")
struct WMOpenAppActionTests {
    @Test("throws invalidURL if app has nil URL")
    func nullFilePathError() async {
        let mockApp = WorkspaceApplication(bundleIdentifier: "", displayName: "", applicationURL: nil)
        let fakeWorkspace = FakeWorkspace()

        let action = WMOpenAppAction(app: mockApp, workspace: fakeWorkspace)

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

        let action = WMOpenAppAction(app: mockApp, workspace: fakeWorkspace)

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

        let action = WMOpenAppAction(app: mockApp, workspace: fakeWorkspace)

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

        let action = WMOpenAppAction(app: mockApp, workspace: fakeWorkspace)

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

        let action = WMOpenAppAction(app: mockApp, workspace: fakeWorkspace)

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
        let action = WMOpenAppAction(app: mockApp, workspace: fakeWorkspace)

        try #require(mockApp.applicationURL != nil)
        await #expect(throws: Never.self) { try await action.execute() }
        #expect(fakeWorkspace.didCallOpenApplication)
    }

    @Test("maps WorkspaceApplication launch fields onto OpenConfiguration")
    func mapsLaunchConfiguration() async throws {
        let mockApp = WorkspaceApplication(
            bundleIdentifier: "com.apple.Terminal",
            displayName: "Terminal",
            applicationURL: URL(filePath: "/System/Applications/Utilities/Terminal.app"),
            allowsRunningApplicationSubstitution: false,
            createsNewApplicationInstance: true,
            arguments: ["--args", "hello"],
            environment: ["DAWN_TEST": "1"],
            promptsUserIfNeeded: true
        )
        let fakeWorkspace = FakeWorkspace()
        let action = WMOpenAppAction(app: mockApp, workspace: fakeWorkspace)

        try await action.execute()

        let configuration = try #require(fakeWorkspace.lastConfiguration)
        #expect(configuration.activates == true)
        #expect(configuration.hides == false)
        #expect(configuration.hidesOthers == false)
        #expect(configuration.requiresUniversalLinks == false)
        #expect(configuration.allowsRunningApplicationSubstitution == false)
        #expect(configuration.createsNewApplicationInstance == true)
        #expect(configuration.arguments == ["--args", "hello"])
        #expect(configuration.environment == ["DAWN_TEST": "1"])
        #expect(configuration.promptsUserIfNeeded == true)
    }

    @Test("unhides and activates a hidden running app when substitution is allowed")
    func restoresHiddenRunningApp() async throws {
        let mockApp = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            applicationURL: URL(filePath: "Applications/Safari.app")
        )
        let runningApp = FakeRunningApp(bundleIdentifier: mockApp.bundleIdentifier)
        runningApp.isHidden = true

        let provider = FakeAppProvider()
        provider.appsByBundleIdentifier[mockApp.bundleIdentifier] = [runningApp]
        let fakeWorkspace = FakeWorkspace()

        let action = WMOpenAppAction(app: mockApp, workspace: fakeWorkspace, provider: provider)
        try await action.execute()

        #expect(runningApp.didUnhide)
        #expect(runningApp.didActivate)
        #expect(runningApp.lastActivationOptions == .activateIgnoringOtherApps)
        #expect(!fakeWorkspace.didCallOpenApplication)
    }

    @Test("activates a visible running app without relaunching when substitution is allowed")
    func activatesVisibleRunningApp() async throws {
        let mockApp = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            applicationURL: URL(filePath: "Applications/Safari.app")
        )
        let runningApp = FakeRunningApp(bundleIdentifier: mockApp.bundleIdentifier)
        runningApp.isHidden = false

        let provider = FakeAppProvider()
        provider.appsByBundleIdentifier[mockApp.bundleIdentifier] = [runningApp]
        let fakeWorkspace = FakeWorkspace()

        let action = WMOpenAppAction(app: mockApp, workspace: fakeWorkspace, provider: provider)
        try await action.execute()

        #expect(!runningApp.didUnhide)
        #expect(runningApp.didActivate)
        #expect(!fakeWorkspace.didCallOpenApplication)
    }

    @Test("relaunches when createsNewApplicationInstance is true even if running")
    func createsNewInstanceIgnoresRunningApp() async throws {
        let mockApp = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            applicationURL: URL(filePath: "Applications/Safari.app"),
            createsNewApplicationInstance: true
        )
        let runningApp = FakeRunningApp(bundleIdentifier: mockApp.bundleIdentifier)
        runningApp.isHidden = true

        let provider = FakeAppProvider()
        provider.appsByBundleIdentifier[mockApp.bundleIdentifier] = [runningApp]
        let fakeWorkspace = FakeWorkspace()

        let action = WMOpenAppAction(app: mockApp, workspace: fakeWorkspace, provider: provider)
        try await action.execute()

        #expect(!runningApp.didUnhide)
        #expect(!runningApp.didActivate)
        #expect(fakeWorkspace.didCallOpenApplication)
    }

    @Test("relaunches when substitution is disallowed even if running")
    func disallowedSubstitutionRelaunches() async throws {
        let mockApp = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            applicationURL: URL(filePath: "Applications/Safari.app"),
            allowsRunningApplicationSubstitution: false
        )
        let runningApp = FakeRunningApp(bundleIdentifier: mockApp.bundleIdentifier)
        runningApp.isHidden = true

        let provider = FakeAppProvider()
        provider.appsByBundleIdentifier[mockApp.bundleIdentifier] = [runningApp]
        let fakeWorkspace = FakeWorkspace()

        let action = WMOpenAppAction(app: mockApp, workspace: fakeWorkspace, provider: provider)
        try await action.execute()

        #expect(!runningApp.didUnhide)
        #expect(!runningApp.didActivate)
        #expect(fakeWorkspace.didCallOpenApplication)
    }

    @Test("throws noGUItoShow when unhide fails")
    func unhideFailure() async {
        let mockApp = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            applicationURL: URL(filePath: "Applications/Safari.app")
        )
        let runningApp = FakeRunningApp(bundleIdentifier: mockApp.bundleIdentifier)
        runningApp.isHidden = true
        runningApp.unhideResult = false

        let provider = FakeAppProvider()
        provider.appsByBundleIdentifier[mockApp.bundleIdentifier] = [runningApp]
        let fakeWorkspace = FakeWorkspace()

        let action = WMOpenAppAction(app: mockApp, workspace: fakeWorkspace, provider: provider)
        await #expect(throws: WMActionError.noGUItoShow) {
            try await action.execute()
        }
        #expect(!fakeWorkspace.didCallOpenApplication)
    }
}

final class FakeWorkspace: WorkspaceOpener {
    var didCallOpenApplication: Bool = false
    var lastConfiguration: NSWorkspace.OpenConfiguration?
    var errorToThrow: Error?

    func openApplication(at _: URL,
                         configuration: NSWorkspace.OpenConfiguration) async throws -> NSRunningApplication
    {
        didCallOpenApplication = true
        lastConfiguration = configuration
        if let error = errorToThrow {
            throw error
        }

        return NSRunningApplication()
    }
}
