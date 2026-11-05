import Foundation
import Testing
import libdawn

@testable import dawnApp

@MainActor
@Suite("Settings ViewModel")
struct SettingsViewModelTests {
    @Test("load success copies the full settings draft")
    func loadSuccess() async {
        let seeded = Settings(
            launchAtLogin: true,
            showInMenuBar: false,
            forceAppsToQuit: true,
            analyticsEnabled: true,
            protectedApps: [
                ProtectedApplication(
                    bundleIdentifier: "com.apple.Safari",
                    displayName: "Safari"
                )
            ]
        )
        let client = SettingsViewStoreClientSpy(settings: seeded)
        let viewModel = SettingsViewModel(
            client: client,
            applicationSelector: ApplicationSelectorSpy()
        )

        await viewModel.load()

        #expect(viewModel.draft == seeded)
        #expect(viewModel.error == nil)
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isLoading)
    }

    @Test("load failure maps to loadFailed")
    func loadFailure() async {
        let client = SettingsViewStoreClientSpy()
        client.refreshError = .timeout
        let viewModel = SettingsViewModel(
            client: client,
            applicationSelector: ApplicationSelectorSpy()
        )

        await viewModel.load()

        #expect(viewModel.error == .loadFailed)
        #expect(viewModel.errorMessage == ViewModelError.loadFailed.errorDescription)
        #expect(!viewModel.isLoading)
    }

    @Test("apply success sends the full edited draft")
    func applySuccessSendsFullDraft() async {
        let seeded = Settings(
            launchAtLogin: false,
            showInMenuBar: true,
            forceAppsToQuit: false,
            analyticsEnabled: false,
            protectedApps: [
                ProtectedApplication(
                    bundleIdentifier: "com.apple.Safari",
                    displayName: "Safari"
                )
            ]
        )
        let client = SettingsViewStoreClientSpy(settings: seeded)
        let viewModel = SettingsViewModel(
            client: client,
            applicationSelector: ApplicationSelectorSpy()
        )

        await viewModel.load()
        viewModel.draft.launchAtLogin = true
        viewModel.draft.showInMenuBar = false
        viewModel.draft.forceAppsToQuit = true
        viewModel.draft.analyticsEnabled = true
        await viewModel.setSettings()

        let expected = Settings(
            launchAtLogin: true,
            showInMenuBar: false,
            forceAppsToQuit: true,
            analyticsEnabled: true,
            protectedApps: seeded.protectedApps
        )

        #expect(client.updatedSettings == [expected])
        #expect(viewModel.error == nil)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("add protected app uses the system application selector")
    func addProtectedAppFromSelector() async {
        let application = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            applicationURL: URL(fileURLWithPath: "/Applications/Safari.app")
        )
        let selector = ApplicationSelectorSpy(result: application)
        let client = SettingsViewStoreClientSpy()
        let viewModel = SettingsViewModel(
            client: client,
            applicationSelector: selector
        )

        await viewModel.load()
        await viewModel.addProtectedApp()
        await viewModel.setSettings()

        #expect(selector.callCount == 1)
        #expect(client.updatedSettings.count == 1)
        #expect(client.updatedSettings[0].protectedApps.count == 1)
        #expect(client.updatedSettings[0].protectedApps[0].displayName == "Safari")
        #expect(client.updatedSettings[0].protectedApps[0].bundleIdentifier == "com.apple.Safari")
        #expect(viewModel.applicationSelectionError == nil)
    }

    @Test("add protected app ignores a duplicate bundle identifier")
    func addProtectedAppIgnoresDuplicate() async {
        let existing = ProtectedApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari"
        )
        let application = WorkspaceApplication(
            bundleIdentifier: "COM.APPLE.SAFARI",
            displayName: "Safari",
            applicationURL: URL(fileURLWithPath: "/Applications/Safari.app")
        )
        let selector = ApplicationSelectorSpy(result: application)
        let viewModel = SettingsViewModel(
            client: SettingsViewStoreClientSpy(settings: Settings(protectedApps: [existing])),
            applicationSelector: selector
        )

        await viewModel.load()
        await viewModel.addProtectedApp()

        #expect(viewModel.draft.protectedApps == [existing])
    }

    @Test("cancelled application selection changes nothing")
    func cancelApplicationSelection() async {
        let selector = ApplicationSelectorSpy(result: nil)
        let viewModel = SettingsViewModel(
            client: SettingsViewStoreClientSpy(),
            applicationSelector: selector
        )

        await viewModel.load()
        await viewModel.addProtectedApp()

        #expect(viewModel.draft.protectedApps.isEmpty)
        #expect(viewModel.applicationSelectionError == nil)
    }

    @Test("application selection failure is exposed")
    func applicationSelectionFailure() async {
        let selector = ApplicationSelectorSpy(error: .invalidApplication)
        let viewModel = SettingsViewModel(
            client: SettingsViewStoreClientSpy(),
            applicationSelector: selector
        )

        await viewModel.load()
        await viewModel.addProtectedApp()

        #expect(viewModel.draft.protectedApps.isEmpty)
        #expect(viewModel.applicationSelectionError == .invalidApplication)
    }

    @Test("apply failure maps to persistenceFailed and keeps draft")
    func applyFailure() async {
        let seeded = Settings(
            launchAtLogin: true,
            showInMenuBar: false,
            protectedApps: [
                ProtectedApplication(
                    bundleIdentifier: "com.apple.Safari",
                    displayName: "Safari"
                )
            ]
        )
        let client = SettingsViewStoreClientSpy(settings: seeded)
        client.updateError = .timeout
        let viewModel = SettingsViewModel(
            client: client,
            applicationSelector: ApplicationSelectorSpy()
        )

        await viewModel.load()
        viewModel.draft.launchAtLogin = false
        viewModel.draft.forceAppsToQuit = true
        await viewModel.setSettings()

        #expect(viewModel.draft.launchAtLogin == false)
        #expect(viewModel.draft.forceAppsToQuit)
        #expect(viewModel.draft.protectedApps == seeded.protectedApps)
        #expect(viewModel.error == .persistenceFailed)
        #expect(viewModel.errorMessage == ViewModelError.persistenceFailed.errorDescription)
        #expect(client.updatedSettings.isEmpty)
    }

    @Test("reset settings restores document defaults")
    func resetSettingsToDefaults() async {
        let client = SettingsViewStoreClientSpy(
            settings: Settings(
                launchAtLogin: true,
                showInMenuBar: false,
                forceAppsToQuit: true,
                analyticsEnabled: true,
                protectedApps: [
                    ProtectedApplication(
                        bundleIdentifier: "com.apple.Safari",
                        displayName: "Safari"
                    )
                ]
            )
        )
        let viewModel = SettingsViewModel(
            client: client,
            applicationSelector: ApplicationSelectorSpy()
        )

        await viewModel.load()
        viewModel.resetSettingsToDefaults()

        #expect(viewModel.draft == Settings())
    }

    @Test("remove protected app updates the draft")
    func removeProtectedApp() async {
        let app = ProtectedApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari"
        )
        let viewModel = SettingsViewModel(
            client: SettingsViewStoreClientSpy(settings: Settings(protectedApps: [app])),
            applicationSelector: ApplicationSelectorSpy()
        )

        await viewModel.load()
        viewModel.removeProtectedApp(id: app.id)

        #expect(viewModel.draft.protectedApps.isEmpty)
    }
}

@MainActor
private final class SettingsViewStoreClientSpy: SettingsViewStoreClient {
    private(set) var settings: Settings
    private(set) var error: SettingsViewStoreError?
    private(set) var updatedSettings: [Settings] = []

    var refreshError: SettingsViewStoreError?
    var updateError: SettingsViewStoreError?

    init(settings: Settings = Settings()) {
        self.settings = settings
    }

    func refresh() async {
        if let refreshError {
            error = refreshError
            return
        }

        error = nil
    }

    func updateSettings(_ settings: Settings) async throws(SettingsViewStoreError) {
        if let updateError {
            error = updateError
            throw updateError
        }

        updatedSettings.append(settings)
        self.settings = settings
        error = nil
    }
}

@MainActor
private final class ApplicationSelectorSpy: ApplicationSelecting {
    private(set) var callCount = 0

    private let result: WorkspaceApplication?
    private let error: ApplicationSelectionError?

    init(result: WorkspaceApplication? = nil, error: ApplicationSelectionError? = nil) {
        self.result = result
        self.error = error
    }

    func selectApplication() async throws -> WorkspaceApplication? {
        callCount += 1

        if let error {
            throw error
        }

        return result
    }
}
