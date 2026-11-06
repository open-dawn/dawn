import AppKit
import Foundation
import libdawn

struct WMResetWindowsAction: WMAction {
    let activationPolicy: WorkspaceActivationPolicy
    let keepBundleIdentifiers: Set<String>
    let protectedBundleIdentifiers: Set<String>
    private let provider: ApplicationProvider

    init(
        activationPolicy: WorkspaceActivationPolicy = .hide,
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
        activationPolicy: WorkspaceActivationPolicy,
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
            let hidden = nonMemberRunningApplications().map { $0.hide() }
            if hidden.contains(false) {
                throw WMActionError.noGUItoShow
            }
        case .close:
            let terminated = nonMemberRunningApplications().map { $0.terminate() }
            if terminated.contains(false) {
                throw WMActionError.permissionDenied
            }
        }
    }

    private func nonMemberRunningApplications() -> [any RunningApplicationControlling] {
        let preserved = keepBundleIdentifiers.union(protectedBundleIdentifiers)

        return provider.runningApplications().filter { app in
            guard app.activationPolicy == .regular else { return false }
            guard let bundleIdentifier = app.bundleIdentifier else { return false }
            return !preserved.contains(bundleIdentifier)
        }
    }
}
