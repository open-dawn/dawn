import SwiftUI
import libdawn

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

private struct SettingsContent: View {
    @Bindable var viewModel: SettingsViewModel

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
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .disabled(viewModel.isLoading)

            if let selectionError = viewModel.applicationSelectionError {
                Text(selectionError.localizedDescription)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
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
