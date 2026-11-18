import AppKit
import libdawn
import libdawnUI
import SwiftUI

struct SettingsView: View {
    @Environment(SettingsViewStore.self)
    private var settingsStore

    @Environment(AccessibilityPermissionService.self)
    private var accessibilityPermissionService

    @Environment(SettingsEventBusService.self)
    private var eventBusService

    @State private var viewModel: SettingsViewModel?
    @State private var commandLineTool = CommandLineToolInstallModel()

    var body: some View {
        Group {
            if let viewModel {
                SettingsContent(
                    viewModel: viewModel,
                    commandLineTool: commandLineTool,
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
        .task {
            await commandLineTool.refresh()
        }
    }
}

struct SettingsContent: View {
    @Bindable var viewModel: SettingsViewModel
    let commandLineTool: CommandLineToolInstallModel
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
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                settingsForm

                if commandLineTool.showsBanner {
                    CommandLineToolBanner(model: commandLineTool)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
            accessibilitySection
        }
        .disabled(interactionsDisabled)
        .opacity(isAgentConnected ? 1 : 0.45)
    }

    private var generalSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("General")

            VStack(spacing: 16) {
                settingsToggleRow(
                    title: "Show menu bar icon",
                    systemImage: "menubar.dock.rectangle",
                    isOn: draftBinding(\.showInMenuBar)
                )
                settingsToggleRow(
                    title: "Force apps to quit",
                    systemImage: "xmark.app",
                    isOn: draftBinding(\.forceAppsToQuit)
                )
                settingsToggleRow(
                    title: "Analytics enabled",
                    systemImage: "chart.bar",
                    isOn: draftBinding(\.analyticsEnabled)
                )
            }
        }
    }

    private var protectedAppsSection: some View {
        ContextDetailApplicationList(
            title: "Protected applications",
            subtitle: "(not affected by workspace changes)",
            titleFont: DawnTextStyle.settingsSectionTitle,
            titleColor: DawnColors.primaryForeground,
            fillsAvailableWidth: true,
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

    private var accessibilitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Other options")

            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "hand.raised")
                        .font(DawnTextStyle.actionIcon)
                        .foregroundStyle(DawnColors.primaryForeground)
                        .frame(width: 24, height: 24)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accessibility permission")
                            .font(DawnTextStyle.primary)
                            .foregroundStyle(DawnColors.primaryForeground)

                        Text(accessibilityStatusDescription)
                            .font(DawnTextStyle.primary)
                            .foregroundStyle(DawnColors.secondaryForeground)
                    }
                }

                Spacer()

                DButton(style: .primary) {
                    Task {
                        await accessibilityPermissionService.promptTrust()
                    }
                } content: {
                    Text(
                        accessibilityPermissionService.isTrusted == true
                            ? "Recheck"
                            : "Grant access"
                    )
                }
                .disabled(
                    accessibilityPermissionService.isLoading || !isAgentConnected
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .accessibilityElement(children: .contain)
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
            .font(DawnTextStyle.settingsSectionTitle)
            .foregroundStyle(DawnColors.primaryForeground)
    }

    private func settingsToggleRow(
        title: String,
        systemImage: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(DawnTextStyle.actionIcon)
                    .foregroundStyle(DawnColors.primaryForeground)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                Text(title)
                    .font(DawnTextStyle.primary)
                    .foregroundStyle(DawnColors.primaryForeground)
            }

            Spacer()

            Toggle(title, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private func draftBinding(
        _ keyPath: WritableKeyPath<libdawn.Settings, Bool>
    ) -> Binding<Bool> {
        Binding(
            get: { viewModel.draft[keyPath: keyPath] },
            set: { newValue in
                viewModel.updateDraft { draft in
                    draft[keyPath: keyPath] = newValue
                }
            }
        )
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

private struct CommandLineToolBanner: View {
    let model: CommandLineToolInstallModel

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CLI is available to install.")
                    .font(DawnTextStyle.primary)
                    .foregroundStyle(DawnColors.primaryForeground)

                Text("Adds the command to Terminal.")
                    .font(DawnTextStyle.primary)
                    .foregroundStyle(DawnColors.secondaryForeground)

                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .font(DawnTextStyle.primary)
                        .foregroundStyle(DawnColors.dangerForeground)
                }
            }

            Spacer(minLength: 12)

            DButton(style: .primary) {
                Task {
                    await model.install()
                }
            } content: {
                Text("Install")
            }
            .disabled(model.isInstalling)
            .opacity(model.isInstalling ? 0.25 : 1)
            .accessibilityLabel("Install dawncli")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
