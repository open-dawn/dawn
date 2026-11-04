import SwiftUI
import libdawn
import libdawnUI

struct SettingsView: View {
    @Environment(SettingsViewStore.self)
    private var settingsStore

    @Environment(AccessibilityPermissionService.self)
    private var accessibilityPermissionService

    @State private var viewModel: SettingsViewModel?

    var body: some View {
        Group {
            if let viewModel {
                SettingsContent(
                    viewModel: viewModel,
                    accessibilityPermissionService: accessibilityPermissionService
                )
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

private struct SettingsContent: View {
    @Bindable var viewModel: SettingsViewModel
    let accessibilityPermissionService: AccessibilityPermissionService

    var body: some View {
        VStack {
            Form {
                Section("Global") {
                    Toggle("Open at login", isOn: $viewModel.draft.launchAtLogin)
                    Toggle("Show menu bar icon", isOn: $viewModel.draft.showInMenuBar)
                    Toggle("Force apps to quit", isOn: $viewModel.draft.forceAppsToQuit)
                    Toggle("Analytics", isOn: $viewModel.draft.analyticsEnabled)
                }

                Section("Protected apps") {
                    HStack {
                        Text("Apps that stay open across context switches")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            Task {
                                await viewModel.addProtectedApp()
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .disabled(viewModel.isLoading)
                        .accessibilityLabel("Add protected app")
                    }

                    ForEach(viewModel.draft.protectedApps) { app in
                        protectedAppRow(app)
                    }
                }

                Section("Permissions") {
                    accessibilityPermissionRow
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .disabled(viewModel.isLoading)

            if let selectionError = viewModel.applicationSelectionError {
                Text(selectionError.localizedDescription)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Reset defaults", systemImage: "arrow.circlepath") {
                    viewModel.resetSettingsToDefaults()
                }
                .tint(.yellow)
                .disabled(viewModel.isLoading)

                Button("Apply settings") {
                    Task {
                        await viewModel.setSettings()
                    }
                }
                .tint(.green)
                .disabled(viewModel.isLoading)
            }
        }
    }

    private var accessibilityPermissionRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Accessibility")
                    Text(accessibilityStatusDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                DButton(style: .secondary) {
                    Task {
                        await accessibilityPermissionService.promptTrust()
                    }
                } content: {
                    Text(accessibilityPermissionService.isTrusted == true ? "Recheck" : "Grant Access")
                }
                .disabled(accessibilityPermissionService.isLoading)
            }

            if let message = accessibilityPermissionService.error?.errorDescription {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(DawnColors.dangerForeground)
            }
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

    @ViewBuilder
    private func protectedAppRow(_ app: ProtectedApplication) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(app.displayName)

                Text(app.bundleIdentifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(
                "Delete \(app.displayName)",
                systemImage: "trash",
                role: .destructive
            ) {
                viewModel.removeProtectedApp(id: app.id)
            }
            .tint(.red)
            .labelStyle(.iconOnly)
            .disabled(viewModel.isLoading)
        }
    }
}
