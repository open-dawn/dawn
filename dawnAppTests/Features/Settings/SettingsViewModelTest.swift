@testable import dawnApp
import Testing

@Suite("Settings ViewModel")
struct SettingsViewModelTests {
    @Test("starts a view model with no error")
    func initialState() {
        let viewModel = SettingsViewModel()
        #expect(viewModel.error == nil)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
        #expect(!viewModel.sectionsWithSettings.isEmpty)
    }

    @Test("reset all settings to default value")
    func resetSettingsToDefault() {
        let viewModel = SettingsViewModel()
        // Change values to random
        for section in viewModel.sectionsWithSettings {
            for setting in section.settings {
                let anyKeyPath = setting.inputType.getKeyPath(viewModel)
                if let boolPath = anyKeyPath as? ReferenceWritableKeyPath<SettingsViewModel, Bool> {
                    viewModel[keyPath: boolPath].toggle()
                } else if let stringPath = anyKeyPath
                    as? ReferenceWritableKeyPath<SettingsViewModel, String>
                {
                    viewModel[keyPath: stringPath] += "__"
                }
            }
        }

        viewModel.resetSettingsToDefaults()

        for section in viewModel.sectionsWithSettings {
            for setting in section.settings {
                let value = setting.inputType.getAssociatedValue(viewModel) as? AnyHashable
                let defaultValue = setting.defaultValue as? AnyHashable

                #expect(value != nil)
                #expect(defaultValue != nil)
                #expect(value == defaultValue)
            }
        }

        #expect(viewModel.error == nil)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("resetSettingToDefault sets error when default type mismatches")
    func resetSettingToDefaultSetsErrorWhenTypeMismatches() {
        let viewModel = SettingsViewModel()
        let toggle = viewModel.sectionsWithSettings[0].settings[0]
        let invalid = SettingItem("Invalid item", desc: "Invalid description",
                                  type: toggle.inputType,
                                  defaultValue: "string isnt a bool")
        viewModel.resetSettingToDefault(invalid)

        #expect(viewModel.error == ViewModelError.invalidSetting)
        #expect(viewModel.errorMessage != nil)
    }
}
