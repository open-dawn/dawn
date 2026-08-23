import Testing
@testable import PaSettingsUI

@Suite("GeneralSettings ViewModel")
struct GeneralSettingsViewModelTests{
    @Test("starts a view model and check defaults values")
    func initialState() {
        let vm = GeneralSettingsView.ViewModel()
        #expect(vm.error == nil)
        #expect(vm.errorMessage == nil)
        #expect(vm.isLoading == false)
        #expect(!vm.sectionsWithSettings.isEmpty)
    }
    
    @Test("reset all settings to default value")
    func resetSettingsToDefault() {
        let vm = GeneralSettingsView.ViewModel()
        // Change values to random
        for section in vm.sectionsWithSettings {
            for setting in section.settings {
                let anyKeyPath = setting.inputType.getKeyPath(vm)
                if let boolPath = anyKeyPath as? ReferenceWritableKeyPath<GeneralSettingsView.ViewModel, Bool> {
                    vm[keyPath: boolPath].toggle()
                } else if let stringPath = anyKeyPath as? ReferenceWritableKeyPath<GeneralSettingsView.ViewModel, String> {
                    vm[keyPath: stringPath] += "__"
                }
            }
        }

        vm.resetSettingsToDefaults()

        for section in vm.sectionsWithSettings {
            for setting in section.settings {
                let value = setting.inputType.getAssociatedValue(vm) as? AnyHashable
                let defaultValue = setting.defaultValue as? AnyHashable

                #expect(value != nil)
                #expect(defaultValue != nil)
                #expect(value == defaultValue)
            }
        }
    }
}
