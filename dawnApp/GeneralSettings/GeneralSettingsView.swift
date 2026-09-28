import SwiftUI

struct GeneralSettingsView: View {
    @State private var viewModel = Self.ViewModel()

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

    @ViewBuilder
    private func settingRow(_ setting: SettingItem<Self.ViewModel>) -> some View {
        HStack {
            switch setting.inputType {
            case .toggle(let keyPath):
                Toggle(setting.title, isOn: Binding(
                    get: { viewModel[keyPath: keyPath] },
                    set: { viewModel[keyPath: keyPath] = $0 }
                ))

                Button("Reset \(setting.title) to default value", systemImage: "arrow.circlepath") {
                    viewModel.resetSettingToDefault(setting)
                }
                .labelStyle(.iconOnly)
                .disabled(viewModel[keyPath: keyPath] == setting.defaultValue as? Bool)

            case .textField(let keyPath):
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
