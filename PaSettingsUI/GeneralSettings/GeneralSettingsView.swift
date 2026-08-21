import SwiftUI

struct GeneralSettingsView: View {
    @State private var vm = Self.ViewModel()

    var body: some View {
        VStack {
            Form {
                ForEach(vm.sectionsWithSettings, id: \.id) { section in
                    Section(section.title) {
                        ForEach(section.settings, id: \.id) { setting in
                            SettingRow(setting)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            
            Spacer()

            HStack {
                Spacer()
                Button("Reset defaults", systemImage: "arrow.circlepath") {
                    vm.resetSettingsToDefaults()
                }
                .tint(.yellow)

                Button("Apply settings") {
                    vm.setSettings()
                }
                .tint(.green)
            }
        }
    }

    @ViewBuilder
    private func SettingRow(_ setting: SettingItem<Self.ViewModel>) -> some View {
        switch setting.inputType {
        case .toggle(let keyPath):
            Toggle(setting.title, isOn: Binding(
                get: { vm[keyPath: keyPath] },
                set: { vm[keyPath: keyPath] = $0 }
            ))
        case .textField(let keyPath):
            TextField(setting.title, text: Binding(
                get: { vm[keyPath: keyPath] },
                set: { vm[keyPath: keyPath] = $0 }
            ))
        }
    }
}
