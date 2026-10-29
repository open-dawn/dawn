import AppKit
@testable import dawnAgent
import Foundation
import libdawn
import Testing

@Suite("WMResetWindowsAction Testing")
struct WMResetWindowsActionTests {
    @Test("hide policy hides non-member apps and skips protected ones")
    func hidePolicyHidesNonMembers() throws {
        let safari = FakeRunningApp(bundleIdentifier: "com.apple.Safari")
        let safari = FakeRunningApp(bundleIdentifier: "com.apple.Safari")
        let finder = FakeRunningApp(bundleIdentifier: "com.apple.finder")

        let provider = FakeAppProvider()
        provider.allApps = [safari, safari, finder]

        let action = WMResetWindowsAction(
            activationPolicy: .hide,
            keepBundleIdentifiers: ["com.apple.Safari"],
            protectedBundleIdentifiers: ["com.apple.finder"],
            provider: provider
        )

        try action.execute()

        #expect(safari.hideCallCount == 0)
        #expect(safari.hideCallCount == 1)
        #expect(finder.hideCallCount == 0)
        #expect(safari.terminateCallCount == 0)
    }

    @Test("merge policy leaves running apps untouched")
    func mergePolicyIsNoOp() throws {
        let safari = FakeRunningApp(bundleIdentifier: "com.apple.Safari")
        let provider = FakeAppProvider()
        provider.allApps = [safari]

        let action = WMResetWindowsAction(
            activationPolicy: .merge,
            keepBundleIdentifiers: [],
            protectedBundleIdentifiers: [],
            provider: provider
        )

        try action.execute()

        #expect(safari.hideCallCount == 0)
        #expect(safari.terminateCallCount == 0)
    }

    @Test("close policy terminates non-member apps")
    func closePolicyTerminatesNonMembers() throws {
        let safari = FakeRunningApp(bundleIdentifier: "com.apple.Safari")
        let safari = FakeRunningApp(bundleIdentifier: "com.apple.Safari")

        let provider = FakeAppProvider()
        provider.allApps = [safari, safari]

        let action = WMResetWindowsAction(
            activationPolicy: .close,
            keepBundleIdentifiers: ["com.apple.Safari"],
            protectedBundleIdentifiers: [],
            provider: provider
        )

        try action.execute()

        #expect(safari.terminateCallCount == 0)
        #expect(safari.terminateCallCount == 1)
        #expect(safari.hideCallCount == 0)
    }

    @Test("hide policy ignores accessory and prohibited processes")
    func hidePolicySkipsNonRegularApps() throws {
        let menuExtra = FakeRunningApp(bundleIdentifier: "com.example.menu")
        menuExtra.activationPolicy = .accessory
        let background = FakeRunningApp(bundleIdentifier: "com.example.agent")
        background.activationPolicy = .prohibited
        let safari = FakeRunningApp(bundleIdentifier: "com.apple.Safari")

        let provider = FakeAppProvider()
        provider.allApps = [menuExtra, background, safari]

        let action = WMResetWindowsAction(
            activationPolicy: .hide,
            protectedBundleIdentifiers: [],
            provider: provider
        )

        try action.execute()

        #expect(menuExtra.hideCallCount == 0)
        #expect(background.hideCallCount == 0)
        #expect(safari.hideCallCount == 1)
    }

    @Test("hide policy throws when hide returns false")
    func hideFailureThrows() {
        let safari = FakeRunningApp(bundleIdentifier: "com.apple.Safari")
        safari.hideResult = false

        let provider = FakeAppProvider()
        provider.allApps = [safari]

        let action = WMResetWindowsAction(
            activationPolicy: .hide,
            protectedBundleIdentifiers: [],
            provider: provider
        )

        #expect(throws: WMActionError.noGUItoShow) {
            try action.execute()
        }
    }
}
