#if DEBUG

import SwiftUI
import libdawn
import libdawnUI

#Preview("Settings / Empty") {
    SettingsViewPreviewHost(
        baseline: libdawn.Settings(
            launchAtLogin: false,
            showInMenuBar: false,
            forceAppsToQuit: false,
            analyticsEnabled: false,
            protectedApps: []
        )
    )
}

#Preview("Settings / Five Apps Dirty") {
    SettingsViewPreviewHost(
        baseline: libdawn.Settings(
            launchAtLogin: false,
            showInMenuBar: true,
            forceAppsToQuit: false,
            analyticsEnabled: false,
            protectedApps: []
        )
    ) { viewModel in
        viewModel.draft.showInMenuBar = true
        viewModel.draft.forceAppsToQuit = false
        viewModel.draft.analyticsEnabled = true
        viewModel.draft.protectedApps = SettingsViewPreviewData.fiveApps
    }
}

private struct SettingsViewPreviewHost: View {
    private let baseline: libdawn.Settings
    private let configure: ((SettingsViewModel) -> Void)?

    @State private var viewModel: SettingsViewModel?
    @State private var commandLineTool = CommandLineToolInstallModel(
        installer: PreviewCommandLineToolInstaller()
    )

    init(
        baseline: libdawn.Settings,
        configure: ((SettingsViewModel) -> Void)? = nil
    ) {
        self.baseline = baseline
        self.configure = configure
    }

    var body: some View {
        Group {
            if let viewModel {
                SettingsContent(
                    viewModel: viewModel,
                    commandLineTool: commandLineTool,
                    accessibilityPermissionService: AccessibilityPermissionService(
                        bus: PreviewSettingsEventBus()
                    ),
                    isAgentConnected: true
                )
            } else {
                ProgressView()
            }
        }
        .padding(24)
        .frame(width: 720, height: 640)
        .background(DawnColors.primaryBackground)
        .preferredColorScheme(.dark)
        .task {
            guard viewModel == nil else {
                return
            }

            let client = PreviewSettingsViewStoreClient(settings: baseline)
            let loaded = SettingsViewModel(
                client: client,
                applicationSelector: PreviewApplicationSelector()
            )
            await loaded.load()
            configure?(loaded)
            viewModel = loaded
        }
    }
}

private enum SettingsViewPreviewData {
    static let fiveApps: [ProtectedApplication] = [
        ProtectedApplication(
            bundleIdentifier: "com.nordvpn.macos",
            displayName: "Nord Vpn"
        ),
        ProtectedApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari"
        ),
        ProtectedApplication(
            bundleIdentifier: "com.apple.Music",
            displayName: "Music"
        ),
        ProtectedApplication(
            bundleIdentifier: "com.apple.Notes",
            displayName: "Notes"
        ),
        ProtectedApplication(
            bundleIdentifier: "com.apple.mail",
            displayName: "Mail"
        ),
    ]
}

@MainActor
private final class PreviewSettingsViewStoreClient: SettingsViewStoreClient {
    private(set) var settings: libdawn.Settings
    private(set) var error: SettingsViewStoreError?

    init(settings: libdawn.Settings) {
        self.settings = settings
    }

    func refresh() async {
        error = nil
    }

    func updateSettings(_ settings: libdawn.Settings) async throws(SettingsViewStoreError) {
        self.settings = settings
        error = nil
    }
}

private struct PreviewCommandLineToolInstaller: CommandLineToolInstalling {
    func lookup() async throws -> CommandLineToolLookup {
        .missing
    }

    func installLink(from _: URL, to _: URL) async throws(CommandLineToolInstallError) {}
}

@MainActor
private final class PreviewApplicationSelector: ApplicationSelecting {
    func selectApplication() async throws -> WorkspaceApplication? {
        nil
    }
}

@MainActor
private final class PreviewSettingsEventBus: SettingsEventBus {
    func addListener(_: Listener, kinds _: Set<EventKind>?) {}

    func removeListener(_: Listener) {}

    func ask(_ event: Event, timeout _: Duration) async throws -> Event {
        switch event {
        case .getAccessibilityStatus:
            .accessibilityStatus(AccessibilityStatusEvent(isTrusted: true))
        default:
            event
        }
    }
}

#endif
