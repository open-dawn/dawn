import Foundation
import SwiftUI

extension GeneralSettingsView {
    @Observable
    final class ViewModel: BaseViewModel {
        private(set) var openAtLogin: Bool
        private(set) var defaultContextName: String

        var sectionsWithSettings: [SettingSection<ViewModel>]

        private(set) var error: NSError?
        private(set) var errorMessage: String?
        private(set) var isLoading: Bool

        init() {
            self.isLoading = true
            defer { self.isLoading = false }

            self.openAtLogin = false
            self.defaultContextName = "Context #id"
            self.error = nil
            self.errorMessage = nil
            self.sectionsWithSettings = [
                SettingSection(
                    title: "Global",
                    settings: [
                        SettingItem("Open at login", desc: "", type: .toggle(\.openAtLogin), defaultValue: false),
                        SettingItem("Default name", desc: "", type: .textField(\.defaultContextName), defaultValue: "Name")
                    ]
                )
            ]

            try! self.getCurrentSettings()
        }

        // MARK: - Sync function
        public func setSettings() {
            // TODO: implement this function
            print("Calling setSettings()")
            for section in sectionsWithSettings {
                for setting in section.settings {
                    print("\"\(setting.title)\" with value \(setting.inputType.getAssociatedValue(self))")
                }
            }
        }

        public func resetSettingsToDefaults() {
            // TODO: implement this function with settings storage
            for section in sectionsWithSettings {
                for setting in section.settings {
                    self.resetSettingToDefault(setting)
                }
            } 
        }

        public func getCurrentSettings() throws {
            // TODO: implement this function
        }

        public func resetSettingToDefault(_ setting: SettingItem<ViewModel>) {
            let anyKeyPath = setting.inputType.getKeyPath(self)
            
            if let boolPath = anyKeyPath as? ReferenceWritableKeyPath<ViewModel, Bool>,
               let boolValue = setting.defaultValue as? Bool {
                self[keyPath: boolPath] = boolValue
                
            } else if let stringPath = anyKeyPath as? ReferenceWritableKeyPath<ViewModel, String>,
                      let stringValue = setting.defaultValue as? String {
                self[keyPath: stringPath] = stringValue
            }
        }
    }
}
