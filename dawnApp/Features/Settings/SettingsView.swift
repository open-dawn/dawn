import AppKit
import SwiftUI
import libdawn
import libdawnUI

struct SettingsView: View {
    @Environment(SettingsViewStore.self)
    private var settingsStore

    @Environment(AccessibilityPermissionService.self)
    private var accessibilityPermissionService

    @Environment(SettingsEventBusService.self)
    private var eventBusService

    @State private var viewModel: SettingsViewModel?

    var body: some View {
        Group {
            if let viewModel {
                SettingsContent(
                    viewModel: viewModel,
                    accessibilityPermissionService: accessibilityPermissionService,
                    isAgentConnected: eventBusService.isConnected
                )
            } else {
                ProgressView()
            }
        }
        .padding(32)
        .onAppear {
            if viewModel == nil {
                viewModel = SettingsViewModel(client: settingsStore)
            }

            Task {
                await viewModel?.load()
            }
        }
    }
}

struct SettingsContent: View {
    @Bindable var viewModel: SettingsViewModel
    let accessibilityPermissionService: AccessibilityPermissionService
    let isAgentConnected: Bool

    @State private var isApplicationPickerPresented = false

    private var interactionsDisabled: Bool {
        viewModel.isLoading || !isAgentConnected
    }

    private var isShowingImportError: Binding<Bool> {
        Binding(
            get: { viewModel.applicationImportError != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissApplicationImportError()
                }
            }
        )
    }

    var body: some View {
        ZStack {
            settingsForm
                .disabled(interactionsDisabled)
                .opacity(isAgentConnected ? 1 : 0.45)
        }
        .alert(
            "Couldn't Add Application",
            isPresented: isShowingImportError
        ) {
            Button("OK", role: .cancel) {
                viewModel.dismissApplicationImportError()
            }
        } message: {
            Text(viewModel.applicationImportError?.localizedDescription ?? "")
        }
        .sheet(isPresented: $isApplicationPickerPresented) {
            SettingsProtectedApplicationPicker(
                protectedApps: viewModel.draft.protectedApps,
                onConfirm: { selected in
                    viewModel.applyProtectedApplicationSelection(selected)
                    isApplicationPickerPresented = false
                },
                onCancel: {
                    isApplicationPickerPresented = false
                }
            )
        }
    }

    private var settingsForm: some View {
        VStack(alignment: .leading, spacing: 32) {
            generalSettingsSection
            protectedAppsSection
            permissionsSection
            optionsSection
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var generalSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("General Settings")

            VStack(spacing: 12) {
                settingsToggleRow(
                    title: "Show Menu Bar Icon",
                    systemImage: "menubar.dock.rectangle",
                    isOn: $viewModel.draft.showInMenuBar
                )
                settingsToggleRow(
                    title: "Force app to quit",
                    systemImage: "xmark.app",
                    isOn: $viewModel.draft.forceAppsToQuit
                )
                settingsToggleRow(
                    title: "Analytics Enabled",
                    systemImage: "shareplay",
                    isOn: $viewModel.draft.analyticsEnabled
                )
            }
            .padding(.horizontal, 24)
        }
    }

    private var protectedAppsSection: some View {
        ContextDetailApplicationList(
            title: "Protected Apps",
            applications: protectedApplications,
            interactionsDisabled: interactionsDisabled,
            horizontalPadding: 0,
            onAddApplications: {
                isApplicationPickerPresented = true
            },
            onRemoveApplication: { application in
                viewModel.removeProtectedApp(id: application.id)
            },
            onDropApplications: { urls in
                viewModel.addProtectedApplications(at: urls)
            }
        )
    }

    private var protectedApplications: [WorkspaceApplication] {
        viewModel.draft.protectedApps.map { application in
            WorkspaceApplication(
                id: application.id,
                bundleIdentifier: application.bundleIdentifier,
                displayName: application.displayName,
                applicationURL: NSWorkspace.shared.urlForApplication(
                    withBundleIdentifier: application.bundleIdentifier
                )
            )
        }
    }

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Permissions")
            accessibilityPermissionRow
                .padding(.horizontal, 24)
        }
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            DButton(style: .primary) {
                Task {
                    await viewModel.setSettings()
                }
            } content: {
                Text("Save Settings")
                    .frame(maxWidth: .infinity)
            }
            .disabled(!viewModel.hasUnsavedChanges || interactionsDisabled)
            .opacity(viewModel.hasUnsavedChanges && !interactionsDisabled ? 1 : 0.25)
            .accessibilityLabel("Save Settings")
        }
    }

    private var accessibilityPermissionRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Accessibility")
                    .font(DawnTextStyle.body)
                    .foregroundStyle(DawnColors.primaryForeground)
                Text(accessibilityStatusDescription)
                    .font(DawnTextStyle.caption)
                    .foregroundStyle(DawnColors.secondaryForeground)
            }

            Spacer()

            DButton(style: .secondary) {
                Task {
                    await accessibilityPermissionService.promptTrust()
                }
            } content: {
                Text(accessibilityPermissionService.isTrusted == true ? "Recheck" : "Grant Access")
            }
            .disabled(accessibilityPermissionService.isLoading || !isAgentConnected)
        }
    }

    private var accessibilityStatusDescription: String {
        switch accessibilityPermissionService.isTrusted {
        case true:
            "DAWN Agent can control windows and apps."
        case false:
            "DAWN Agent needs Accessibility permission to manage windows."
        case nil:
            "Connect to DAWN Agent to check Accessibility permission."
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(DawnTextStyle.sectionLabel)
            .foregroundStyle(DawnColors.secondaryForeground)
    }

    private func settingsToggleRow(title: String, systemImage: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .resizable()
                .scaledToFit()
                .font(DawnTextStyle.actionIcon)
                .foregroundStyle(DawnColors.primaryForeground)
                .frame(width: 24, height: 16)
                .accessibilityHidden(true)

            Text(title)
                .font(DawnTextStyle.body)
                .foregroundStyle(DawnColors.primaryForeground)

            Spacer()

            Toggle(title, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SettingsProtectedApplicationPicker: View {
    let protectedApps: [ProtectedApplication]
    let onConfirm: ([ProtectedApplication]) -> Void
    let onCancel: () -> Void

    var body: some View {
        ContextApplicationPicker(
            loadApplications: loadInstalledApplications,
            initialSelection: protectedApps.map { creationApplication(from: $0) },
            confirmTitle: "Add",
            onConfirm: { selected in
                onConfirm(selected.map { protectedApplication(from: $0) })
            },
            onCancel: onCancel
        )
        .padding(16)
        .frame(width: 320, height: 600)
        .background {
            DawnColors.primaryBackground
                .ignoresSafeArea()
        }
        .presentationBackground(DawnColors.primaryBackground)
    }

    private func loadInstalledApplications() async throws -> [ContextCreationApplication] {
        try await ApplicationsDirectoryProvider().applications().map {
            creationApplication(from: $0)
        }
    }

    private func creationApplication(
        from application: WorkspaceApplication
    ) -> ContextCreationApplication {
        ContextCreationApplication(
            id: application.id,
            bundleIdentifier: application.bundleIdentifier,
            displayName: application.displayName,
            applicationURL: application.applicationURL
        )
    }

    private func creationApplication(
        from application: ProtectedApplication
    ) -> ContextCreationApplication {
        ContextCreationApplication(
            bundleIdentifier: application.bundleIdentifier,
            displayName: application.displayName
        )
    }

    private func protectedApplication(
        from application: ContextCreationApplication
    ) -> ProtectedApplication {
        ProtectedApplication(
            bundleIdentifier: application.bundleIdentifier,
            displayName: application.displayName
        )
    }
}
