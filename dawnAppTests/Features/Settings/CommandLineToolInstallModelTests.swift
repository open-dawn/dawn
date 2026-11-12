import Foundation
import Testing

@testable import dawnApp

@MainActor
@Suite("Command line tool install model")
struct CommandLineToolInstallModelTests {
    private let bundleCommandURL = URL(filePath: "/Applications/DAWN.app/Contents/MacOS/dawncli")

    @Test("missing command shows the banner")
    func missingCommandShowsBanner() async {
        let model = makeModel(lookups: [.missing])

        await model.refresh()

        #expect(model.showsBanner)
        #expect(model.errorMessage == nil)
        #expect(!model.isInstalling)
    }

    @Test("command from this bundle hides the banner")
    func matchingCommandHidesBanner() async {
        let model = makeModel(lookups: [.resolved(bundleCommandURL)])

        await model.refresh()

        #expect(!model.showsBanner)
        #expect(model.errorMessage == nil)
    }

    @Test("a different dawncli hides the banner")
    func otherCommandHidesBanner() async {
        let model = makeModel(
            lookups: [.resolved(URL(filePath: "/opt/homebrew/bin/dawncli"))]
        )

        await model.refresh()

        #expect(!model.showsBanner)
        #expect(model.errorMessage == nil)
    }

    @Test("a broken symlink shows the banner")
    func brokenSymlinkShowsBanner() async {
        let model = makeModel(lookups: [.brokenSymlink])

        await model.refresh()

        #expect(model.showsBanner)
        #expect(model.errorMessage == nil)
    }

    @Test("install links this bundle and hides the banner when the shell can run it")
    func installLinksBundle() async {
        let installer = CommandLineToolInstallerSpy(
            lookups: [.missing, .resolved(bundleCommandURL)]
        )
        let model = CommandLineToolInstallModel(
            installer: installer,
            bundleCommandURL: bundleCommandURL
        )

        await model.refresh()
        await model.install()

        #expect(await installer.recordedBundleLinks() == [bundleCommandURL])
        #expect(await installer.recordedDestinationLinks() == [CommandLineToolPaths.linkURL])
        #expect(!model.showsBanner)
        #expect(model.errorMessage == nil)
        #expect(!model.isInstalling)
    }

    @Test("install failure stays on the banner")
    func installFailureStaysOnBanner() async {
        let installer = CommandLineToolInstallerSpy(
            lookups: [.missing],
            installError: .failed("Could not install dawncli.")
        )
        let model = CommandLineToolInstallModel(
            installer: installer,
            bundleCommandURL: bundleCommandURL
        )

        await model.refresh()
        await model.install()

        #expect(await installer.recordedBundleLinks() == [bundleCommandURL])
        #expect(await installer.recordedDestinationLinks() == [CommandLineToolPaths.linkURL])
        #expect(model.showsBanner)
        #expect(model.errorMessage == "Could not install dawncli.")
        #expect(!model.isInstalling)
    }

    @Test("canceled authorization leaves the banner without an error")
    func canceledAuthorizationLeavesBanner() async {
        let installer = CommandLineToolInstallerSpy(
            lookups: [.missing],
            installError: .canceled
        )
        let model = CommandLineToolInstallModel(
            installer: installer,
            bundleCommandURL: bundleCommandURL
        )

        await model.refresh()
        await model.install()

        #expect(await installer.recordedBundleLinks() == [bundleCommandURL])
        #expect(await installer.recordedDestinationLinks() == [CommandLineToolPaths.linkURL])
        #expect(model.showsBanner)
        #expect(model.errorMessage == nil)
        #expect(!model.isInstalling)
    }

    private func makeModel(lookups: [CommandLineToolLookup]) -> CommandLineToolInstallModel {
        CommandLineToolInstallModel(
            installer: CommandLineToolInstallerSpy(lookups: lookups),
            bundleCommandURL: bundleCommandURL
        )
    }
}

@Suite("Command line tool lookup")
struct CommandLineToolLookupTests {
    @Test("a failed whence is missing")
    func failedWhenceIsMissing() throws {
        let lookup = try CommandLineToolLookup.interpret(
            standardOutput: "profile noise\n",
            terminationStatus: 1,
            pathExists: { _ in true }
        )

        #expect(lookup == .missing)
    }

    @Test("an existing command resolves past profile output")
    func existingCommandResolves() throws {
        let command = URL(filePath: "/Applications/dawn-cli-lookup-test/dawncli")
        let lookup = try CommandLineToolLookup.interpret(
            standardOutput: "profile noise\n\(command.path(percentEncoded: false))\n",
            terminationStatus: 0,
            pathExists: { _ in true }
        )

        #expect(lookup == .resolved(command))
    }

    @Test("a path that does not exist is a broken symlink")
    func missingPathIsBroken() throws {
        let lookup = try CommandLineToolLookup.interpret(
            standardOutput: "/usr/local/bin/dawncli\n",
            terminationStatus: 0,
            pathExists: { _ in false }
        )

        #expect(lookup == .brokenSymlink)
    }
}

@Suite("Command line tool install script")
struct CommandLineToolInstallScriptTests {
    @Test("the privileged command symlinks the bundle into /usr/local/bin")
    func privilegedCommandSymlinksBundle() {
        let script = CommandLineToolInstallScript.appleScript(
            bundleCommandURL: URL(filePath: "/Applications/DAWN.app/Contents/MacOS/dawncli"),
            linkURL: CommandLineToolPaths.linkURL
        )

        let expected = [
            "do shell script \"mkdir -p '/usr/local/bin'",
            " && ln -sfn '/Applications/DAWN.app/Contents/MacOS/dawncli'",
            " '/usr/local/bin/dawncli'\" with administrator privileges",
        ].joined()

        #expect(script == expected)
    }

    @Test("quotes and apostrophes stay inside the shell command")
    func quotesStayInsideShellCommand() {
        let script = CommandLineToolInstallScript.appleScript(
            bundleCommandURL: URL(filePath: "/tmp/John's \"DAWN\".app/Contents/MacOS/dawncli"),
            linkURL: CommandLineToolPaths.linkURL
        )

        #expect(script.contains(#"ln -sfn '/tmp/John'\\''s \"DAWN\".app/Contents/MacOS/dawncli'"#))
        #expect(script.hasPrefix("do shell script \""))
        #expect(script.hasSuffix("\" with administrator privileges"))
    }

    @Test("an authorization cancel is recognized from osascript")
    func authorizationCancelIsRecognized() {
        let standardError = "0:128: execution error: User canceled. (-128)"

        #expect(CommandLineToolInstallScript.isAuthorizationCanceled(standardError: standardError))
        #expect(!CommandLineToolInstallScript.isAuthorizationCanceled(standardError: "Permission denied"))
    }
}

private actor CommandLineToolInstallerSpy: CommandLineToolInstalling {
    private var lookups: [CommandLineToolLookup]
    private let installError: CommandLineToolInstallError?
    private var bundleLinks: [URL] = []
    private var destinationLinks: [URL] = []

    init(lookups: [CommandLineToolLookup], installError: CommandLineToolInstallError? = nil) {
        self.lookups = lookups
        self.installError = installError
    }

    func recordedBundleLinks() -> [URL] {
        bundleLinks
    }

    func recordedDestinationLinks() -> [URL] {
        destinationLinks
    }

    func lookup() async throws -> CommandLineToolLookup {
        guard !lookups.isEmpty else {
            return .missing
        }

        return lookups.removeFirst()
    }

    func installLink(
        from bundleCommandURL: URL,
        to linkURL: URL
    ) async throws(CommandLineToolInstallError) {
        bundleLinks.append(bundleCommandURL)
        destinationLinks.append(linkURL)

        if let installError {
            throw installError
        }
    }
}
