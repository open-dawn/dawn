import SwiftUI

struct SettingsView: View {
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
