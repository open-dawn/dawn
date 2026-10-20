import Foundation
import SwiftUI

// Pending: create a different struct with settings for testing.
@Observable
final class GeneralSettingsViewModel {
    private(set) var openAtLogin: Bool
    private(set) var defaultContextName: String

    var sectionsWithSettings: [SettingSection<GeneralSettingsViewModel>]

    private(set) var error: ViewModelError?
    private(set) var errorMessage: String?
    private(set) var isLoading: Bool

    init() {
        isLoading = true
        defer { self.isLoading = false }

        openAtLogin = false
        defaultContextName = "Context #id"
        error = nil
        errorMessage = nil
        sectionsWithSettings = [
            SettingSection(
                title: "Global", settings: [
                    SettingItem("Open at login",
                                desc: "",
                                type: .toggle(\.openAtLogin),
                                defaultValue: false),
                    SettingItem("Default name",
                                desc: "",
                                type: .textField(\.defaultContextName),
                                defaultValue: "Name")
                ]
            )
        ]

        do {
            try getCurrentSettings()
        } catch {
            self.error = error
            errorMessage = error.errorDescription
        }
    }

    // MARK: - Sync function

    func setSettings() {
        // Pending: persist current settings.
        print("Calling setSettings()")
        for section in sectionsWithSettings {
            for setting in section.settings {
                print("\"\(setting.title)\" with value \(setting.inputType.getAssociatedValue(self))")
            }
        }
    }

    func resetSettingsToDefaults() {
        // Pending: reset settings using persistent storage.
        for section in sectionsWithSettings {
            for setting in section.settings {
                resetSettingToDefault(setting)
            }
        }
    }

    func getCurrentSettings() throws(ViewModelError) {
        // Pending: implement this function
    }

    func resetSettingToDefault(_ setting: SettingItem<GeneralSettingsViewModel>) {
        let anyKeyPath = setting.inputType.getKeyPath(self)

        if let boolPath = anyKeyPath as? ReferenceWritableKeyPath<GeneralSettingsViewModel, Bool>,
           let boolValue = setting.defaultValue as? Bool
        {
            self[keyPath: boolPath] = boolValue
            return
        }

        if let stringPath = anyKeyPath as? ReferenceWritableKeyPath<GeneralSettingsViewModel, String>,
           let stringValue = setting.defaultValue as? String
        {
            self[keyPath: stringPath] = stringValue
            return
        }

        let invalidError = ViewModelError.invalidSetting
        error = invalidError
        errorMessage = invalidError.errorDescription
    }
}
