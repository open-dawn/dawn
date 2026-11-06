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

    private let protectedAppsColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private var interactionsDisabled: Bool {
        viewModel.isLoading || !isAgentConnected
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            generalSettingsSection
            protectedAppsSection
            permissionsSection
            optionsSection
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .disabled(interactionsDisabled)
        .opacity(isAgentConnected ? 1 : 0.45)
    }

    private var generalSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("General Settings")

            VStack(spacing: 12) {
                settingsToggleRow(
                    title: "Launch at login",
                    systemImage: "power",
                    isOn: $viewModel.draft.launchAtLogin
                )
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
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Protected Apps")

            LazyVGrid(columns: protectedAppsColumns, spacing: 12) {
                ForEach(viewModel.draft.protectedApps) { app in
                    protectedAppCard(app)
                }

                addProtectedAppCard
                #if DEBUG
                addRunningAppsPickerCard
                #endif
            }
            .padding(.horizontal, 12)

            if let selectionError = viewModel.applicationSelectionError {
                Text(selectionError.localizedDescription)
                    .font(DawnTextStyle.caption)
                    .foregroundStyle(DawnColors.dangerForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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

    private var addProtectedAppCard: some View {
        DButton(style: .plain) {
            Task {
                await viewModel.addProtectedApp()
            }
        } content: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(DawnTextStyle.buttonIcon)
                Text("Add new App")
                    .font(DawnTextStyle.body)
            }
            .foregroundStyle(DawnColors.secondaryForeground)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .disabled(viewModel.isLoading)
        .accessibilityLabel("Add new App")
    }

    private var addRunningAppsPickerCard: some View {
        DButton(style: .plain) {
            Task {
                await viewModel.addProtectedAppFromRunning()
            }
        } content: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(DawnTextStyle.buttonIcon)
                Text("running-apps picker")
                    .font(DawnTextStyle.body)
            }
            .foregroundStyle(DawnColors.secondaryForeground)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .disabled(viewModel.isLoading)
        .accessibilityLabel("running-apps picker")
    }

    private func protectedAppCard(_ app: ProtectedApplication) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: icon(for: app))
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)

            Text(app.displayName)
                .font(DawnTextStyle.body)
                .foregroundStyle(DawnColors.primaryForeground)
                .lineLimit(1)

            Spacer(minLength: 0)

            DButton(style: .compactIcon) {
                viewModel.removeProtectedApp(id: app.id)
            } content: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.light))
            }
            .accessibilityLabel("Remove \(app.displayName)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DawnColors.inputBackground)
                .opacity(0.25)
        }
    }

    private func icon(for app: ProtectedApplication) -> NSImage {
        let applicationURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: app.bundleIdentifier
        )

        return applicationURL.map {
            NSWorkspace.shared.icon(forFile: $0.path(percentEncoded: false))
        } ?? NSWorkspace.shared.icon(for: .application)
    }
}
