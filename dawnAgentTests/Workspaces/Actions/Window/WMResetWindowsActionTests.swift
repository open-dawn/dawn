// CURSOR: NEED REVIEW
import AppKit
import Foundation
import libdawn
@testable import dawnAgent
import Testing

@Suite("WMResetWindowsAction Testing")
struct WMResetWindowsActionTests {
    @Test("hide policy hides non-member apps and skips protected ones")
    func hidePolicyHidesNonMembers() throws {
        let safari = FakeRunningApp(bundleIdentifier: "com.apple.Safari")
        let slack = FakeRunningApp(bundleIdentifier: "com.tinyspeck.slackmacgap")
        let finder = FakeRunningApp(bundleIdentifier: "com.apple.finder")

        let provider = FakeAppProvider()
        provider.allApps = [safari, slack, finder]

        let action = WMResetWindowsAction(
            activationPolicy: .hide,
            keepBundleIdentifiers: ["com.apple.Safari"],
            protectedBundleIdentifiers: ["com.apple.finder"],
            provider: provider
        )

        try action.execute()

        #expect(safari.hideCallCount == 0)
        #expect(slack.hideCallCount == 1)
        #expect(finder.hideCallCount == 0)
        #expect(slack.terminateCallCount == 0)
    }

    @Test("merge policy leaves running apps untouched")
    func mergePolicyIsNoOp() throws {
        let slack = FakeRunningApp(bundleIdentifier: "com.tinyspeck.slackmacgap")
        let provider = FakeAppProvider()
        provider.allApps = [slack]

        let action = WMResetWindowsAction(
            activationPolicy: .merge,
            keepBundleIdentifiers: [],
            protectedBundleIdentifiers: [],
            provider: provider
        )

        try action.execute()

        #expect(slack.hideCallCount == 0)
        #expect(slack.terminateCallCount == 0)
    }

    @Test("close policy terminates non-member apps")
    func closePolicyTerminatesNonMembers() throws {
        let safari = FakeRunningApp(bundleIdentifier: "com.apple.Safari")
        let slack = FakeRunningApp(bundleIdentifier: "com.tinyspeck.slackmacgap")

        let provider = FakeAppProvider()
        provider.allApps = [safari, slack]

        let action = WMResetWindowsAction(
            activationPolicy: .close,
            keepBundleIdentifiers: ["com.apple.Safari"],
            protectedBundleIdentifiers: [],
            provider: provider
        )

        try action.execute()

        #expect(safari.terminateCallCount == 0)
        #expect(slack.terminateCallCount == 1)
        #expect(slack.hideCallCount == 0)
    }
}
