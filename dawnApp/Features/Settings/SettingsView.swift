import AppKit
import libdawn
import libdawnUI
import SwiftUI

struct SettingsView: View {
    @Environment(SettingsViewStore.self)
    private var settingsStore

    @State private var viewModel: SettingsViewModel?

    var body: some View {
        Group {
            if let viewModel {
                SettingsContent(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
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

    private let protectedAppsColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            generalSettingsSection
            protectedAppsSection
            optionsSection
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .disabled(viewModel.isLoading)
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
            HStack {
                sectionTitle("Protected Apps")

                Spacer()

                DButton(style: .linkSecondary) {
                    Task {
                        await viewModel.addProtectedApp()
                    }
                } content: {
                    Text("Add New App")
                        .font(DawnTextStyle.sectionLabel)
                }
                .disabled(viewModel.isLoading)
                .accessibilityLabel("Add New App")
            }

            LazyVGrid(columns: protectedAppsColumns, spacing: 12) {
                ForEach(viewModel.draft.protectedApps) { app in
                    protectedAppCard(app)
                }
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
            .disabled(!viewModel.hasUnsavedChanges || viewModel.isLoading)
            .opacity(viewModel.hasUnsavedChanges && !viewModel.isLoading ? 1 : 0.25)
            .accessibilityLabel("Save Settings")
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
