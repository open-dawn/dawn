import Foundation
import SwiftUI

extension GeneralSettingsView {
    @Observable
    final class ViewModel {
        private var openAtLogin: Bool
        private var defaultContextName: String
        let sectionsWithSettings: [SettingSection<ViewModel>]
        var error: NSError?

        init() {
            self.openAtLogin = false
            self.defaultContextName = "Context #id"
            self.error = nil
            self.sectionsWithSettings = [
                SettingSection(
                    title: "Global",
                    settings: [
                        SettingItem("Open at login", desc: "", type: .toggle(\.openAtLogin)),
                        SettingItem("Default context name", desc: "", type: .textField(\.defaultContextName))
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
            // TODO: implement this function
            print("Calling resetSettingsToDefaults()")
        }

        public func getCurrentSettings() throws {
            // TODO: implement this function
        }
    }
}
