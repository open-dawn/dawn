import libdawnUI
import SwiftUI

struct SettingsView: View {
    @Environment(AccessibilityPermissionService.self)
    private var accessibilityPermissionService

    @State private var viewModel = SettingsViewModel()

    var body: some View {
        VStack {
            Form {
                ForEach(viewModel.sectionsWithSettings, id: \.id) { section in
                    Section(section.title) {
                        ForEach(section.settings, id: \.id) { setting in
                            settingRow(setting)
                        }
                    }
                }

                Section("Permissions") {
                    accessibilityPermissionRow
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Spacer()

            HStack {
                Spacer()
                Button("Reset defaults", systemImage: "arrow.circlepath") {
                    viewModel.resetSettingsToDefaults()
                }
                .tint(.yellow)

                Button("Apply settings") {
                    viewModel.setSettings()
                }
                .tint(.green)
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

    private func settingRow(_ setting: SettingItem<SettingsViewModel>) -> some View {
        HStack {
            switch setting.inputType {
            case let .toggle(keyPath):
                Toggle(setting.title, isOn: Binding(
                    get: { viewModel[keyPath: keyPath] },
                    set: { viewModel[keyPath: keyPath] = $0 }
                ))

                Button("Reset \(setting.title) to default value", systemImage: "arrow.circlepath") {
                    viewModel.resetSettingToDefault(setting)
                }
                .labelStyle(.iconOnly)
                .disabled(viewModel[keyPath: keyPath] == setting.defaultValue as? Bool)

            case let .textField(keyPath):
                TextField(setting.title, text: Binding(
                    get: { viewModel[keyPath: keyPath] },
                    set: { viewModel[keyPath: keyPath] = $0 }
                ))
                Button("Reset \(setting.title) to default value", systemImage: "arrow.circlepath") {
                    viewModel.resetSettingToDefault(setting)
                }
                .labelStyle(.iconOnly)
                .disabled(viewModel[keyPath: keyPath] == setting.defaultValue as? String)
            }
        }
        .tint(.gray)
    }
}
