import Foundation
import libdawn
import Testing

@Suite("SettingsClient")
struct SettingsClientTests {
    @Test("get prints the settings")
    func getPrintsSettings() async throws {
        let text = try await SettingsClient.get(json: false) { event in
            #expect(event == .getSettings(GetSettingsEvent()))
            return .settingsFetched(SettingsFetchedEvent(settings: sample))
        }

        #expect(text == """
        Launch at login: false
        Menu bar: true
        Force quit: true
        Analytics: false
        Protected apps:
          Slack (com.tinyspeck.slackmacgap)
        """)
    }

    @Test("set changes one field and writes the whole document")
    func setChangesOneField() async throws {
        let text = try await SettingsClient.set(field: .analytics, value: true, json: false) { event in
            switch event {
            case .getSettings:
                return .settingsFetched(SettingsFetchedEvent(settings: sample))
            case let .updateSettings(payload):
                #expect(payload.settings.analyticsEnabled)
                #expect(payload.settings.forceAppsToQuit)
                #expect(payload.settings.protectedApps.count == 1)
                return .settingsMutationAcknowledgement(.success)
            default:
                throw AgentError.unexpectedResponse(event.kind)
            }
        }

        #expect(text.contains("Analytics: true"))
    }

    @Test("protect add and remove change the protected list")
    func protectChangesTheList() async throws {
        let added = try await SettingsClient.protect(
            bundleIdentifier: "com.apple.mail",
            displayName: "Mail",
            json: false
        ) { event in
            switch event {
            case .getSettings:
                return .availableSettings(AvailableSettingsEvent(settings: Settings()))
            case let .updateSettings(payload):
                #expect(payload.settings.protectedApps.map(\.bundleIdentifier) == ["com.apple.mail"])
                return .settingsMutationAcknowledgement(.success)
            default:
                throw AgentError.unexpectedResponse(event.kind)
            }
        }
        #expect(added.contains("Mail (com.apple.mail)"))

        await #expect(throws: CLIError.protectedAppMissing("com.apple.mail")) {
            try await SettingsClient.unprotect(bundleIdentifier: "com.apple.mail", json: false) { _ in
                .settingsFetched(SettingsFetchedEvent(settings: Settings()))
            }
        }
    }

    private var sample: Settings {
        Settings(
            launchAtLogin: false,
            showInMenuBar: true,
            forceAppsToQuit: true,
            analyticsEnabled: false,
            protectedApps: [
                ProtectedApplication(
                    bundleIdentifier: "com.tinyspeck.slackmacgap",
                    displayName: "Slack"
                )
            ]
        )
    }
}
