import libdawn

actor AppliedSettings {
    static let shared = AppliedSettings()

    private(set) var settings = Settings()

    func update(_ settings: Settings) {
        self.settings = settings
    }

    func snapshot() -> Settings {
        settings
    }
}

enum SettingsWindowPolicy {
    static func activationPolicy(
        _ policy: WorkspaceActivationPolicy,
        forceAppsToQuit: Bool
    ) -> WorkspaceActivationPolicy {
        if forceAppsToQuit, policy == .hide {
            return .close
        }

        return policy
    }

    static func protectedBundleIdentifiers(extra: [ProtectedApplication]) -> Set<String> {
        WMProtectedApplications.bundleIdentifiers.union(
            extra.map(\.bundleIdentifier)
        )
    }
}
