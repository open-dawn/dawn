import Foundation
import SwiftUI

@Observable
final class SettingsViewModel {
    private(set) var openAtLogin: Bool
    private(set) var defaultContextName: String

    var sectionsWithSettings: [SettingSection<SettingsViewModel>]

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
        for section in sectionsWithSettings {
            for setting in section.settings {
                resetSettingToDefault(setting)
            }
        }
    }

    func getCurrentSettings() throws(ViewModelError) {}

    func resetSettingToDefault(_ setting: SettingItem<SettingsViewModel>) {
        let anyKeyPath = setting.inputType.getKeyPath(self)

        if let boolPath = anyKeyPath as? ReferenceWritableKeyPath<SettingsViewModel, Bool>,
           let boolValue = setting.defaultValue as? Bool
        {
            self[keyPath: boolPath] = boolValue
            return
        }

        if let stringPath = anyKeyPath as? ReferenceWritableKeyPath<SettingsViewModel, String>,
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