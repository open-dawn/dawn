// CURSOR: NEED REVIEW
import AppKit
import Foundation
import libdawn

/// Applies `activationPolicy` to running apps that are not members of the target workspace.
struct WMResetWindowsAction: WMAction {
    let activationPolicy: ActivationPolicy
    let keepBundleIdentifiers: Set<String>
    let protectedBundleIdentifiers: Set<String>
    private let provider: ApplicationProvider

    init(
        activationPolicy: ActivationPolicy = .hide,
        keepBundleIdentifiers: Set<String> = [],
        protectedBundleIdentifiers: Set<String> = WMProtectedApplications.bundleIdentifiers,
        provider: ApplicationProvider = SystemApplicationProvider()
    ) {
        self.activationPolicy = activationPolicy
        self.keepBundleIdentifiers = keepBundleIdentifiers
        self.protectedBundleIdentifiers = protectedBundleIdentifiers
        self.provider = provider
    }

    init(
        activationPolicy: ActivationPolicy,
        keepApplications: [WorkspaceApplication],
        protectedBundleIdentifiers: Set<String> = WMProtectedApplications.bundleIdentifiers,
        provider: ApplicationProvider = SystemApplicationProvider()
    ) {
        self.init(
            activationPolicy: activationPolicy,
            keepBundleIdentifiers: Set(keepApplications.map(\.bundleIdentifier)),
            protectedBundleIdentifiers: protectedBundleIdentifiers,
            provider: provider
        )
    }

    func execute() throws(WMActionError) {
        switch activationPolicy {
        case .merge:
            return
        case .hide:
            for app in nonMemberRunningApplications() {
                _ = app.hide()
            }
        case .close:
            for app in nonMemberRunningApplications() {
                _ = app.terminate()
            }
        }
    }

    private func nonMemberRunningApplications() -> [any RunningApplicationControlling] {
        let preserved = keepBundleIdentifiers.union(protectedBundleIdentifiers)

        return provider.runningApplications().filter { app in
            guard let bundleIdentifier = app.bundleIdentifier else { return false }
            return !preserved.contains(bundleIdentifier)
        }
    }
}
