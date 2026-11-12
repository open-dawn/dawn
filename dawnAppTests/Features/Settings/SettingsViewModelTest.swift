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
        let viewModel = SettingsViewModel(client: client)

        await viewModel.load()

        #expect(viewModel.draft == seeded)
        #expect(!viewModel.hasUnsavedChanges)
        #expect(viewModel.error == nil)
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isLoading)
    }

    @Test("hasUnsavedChanges tracks draft edits and clears after apply")
    func hasUnsavedChangesTracksEdits() async {
        let client = SettingsViewStoreClientSpy(
            settings: Settings(launchAtLogin: false)
        )
        let viewModel = SettingsViewModel(client: client)

        await viewModel.load()
        #expect(!viewModel.hasUnsavedChanges)

        viewModel.draft.launchAtLogin = true
        #expect(viewModel.hasUnsavedChanges)

        await viewModel.setSettings()
        #expect(!viewModel.hasUnsavedChanges)
        #expect(viewModel.error == nil)
    }

    @Test("load failure maps to loadFailed")
    func loadFailure() async {
        let client = SettingsViewStoreClientSpy()
        client.refreshError = .timeout
        let viewModel = SettingsViewModel(client: client)

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
        let viewModel = SettingsViewModel(client: client)

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
        #expect(!viewModel.hasUnsavedChanges)
        #expect(viewModel.error == nil)
        #expect(viewModel.errorMessage == nil)
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
        let viewModel = SettingsViewModel(client: client)

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
        let viewModel = SettingsViewModel(client: client)

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
            client: SettingsViewStoreClientSpy(settings: Settings(protectedApps: [app]))
        )

        await viewModel.load()
        viewModel.removeProtectedApp(id: app.id)

        #expect(viewModel.draft.protectedApps.isEmpty)
    }

    @Test("A protected app selection keeps existing rows, appends new ones, and drops the rest")
    func applyProtectedApplicationSelectionMergesByBundleIdentifier() async {
        let kept = ProtectedApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari"
        )
        let removed = ProtectedApplication(
            bundleIdentifier: "com.apple.mail",
            displayName: "Mail"
        )
        let added = ProtectedApplication(
            bundleIdentifier: "com.apple.Notes",
            displayName: "Notes"
        )
        let viewModel = SettingsViewModel(
            client: SettingsViewStoreClientSpy(
                settings: Settings(protectedApps: [kept, removed])
            )
        )

        await viewModel.load()
        viewModel.applyProtectedApplicationSelection([
            ProtectedApplication(
                bundleIdentifier: kept.bundleIdentifier,
                displayName: "Renamed Safari"
            ),
            added,
        ])

        #expect(viewModel.draft.protectedApps == [kept, added])
        #expect(viewModel.draft.protectedApps.first?.id == kept.id)
        #expect(viewModel.hasUnsavedChanges)
    }

    @Test("A case-different bundle identifier keeps the existing protected app")
    func applyProtectedApplicationSelectionMatchesBundleIdentifierCaseInsensitively() async {
        let existing = ProtectedApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari"
        )
        let viewModel = SettingsViewModel(
            client: SettingsViewStoreClientSpy(
                settings: Settings(protectedApps: [existing])
            )
        )

        await viewModel.load()
        viewModel.applyProtectedApplicationSelection([
            ProtectedApplication(
                bundleIdentifier: "  COM.APPLE.SAFARI  ",
                displayName: "Safari Browser"
            ),
        ])

        #expect(viewModel.draft.protectedApps == [existing])
        #expect(!viewModel.hasUnsavedChanges)
    }

    @Test("A selection that matches the current protected apps does not dirty the draft")
    func applyProtectedApplicationSelectionSkipsUnchangedList() async {
        let safari = ProtectedApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari"
        )
        let mail = ProtectedApplication(
            bundleIdentifier: "com.apple.mail",
            displayName: "Mail"
        )
        let viewModel = SettingsViewModel(
            client: SettingsViewStoreClientSpy(
                settings: Settings(protectedApps: [safari, mail])
            )
        )

        await viewModel.load()
        viewModel.applyProtectedApplicationSelection([
            ProtectedApplication(
                bundleIdentifier: mail.bundleIdentifier,
                displayName: "Mail"
            ),
            ProtectedApplication(
                bundleIdentifier: safari.bundleIdentifier,
                displayName: "Renamed Safari"
            ),
        ])

        #expect(viewModel.draft.protectedApps == [safari, mail])
        #expect(!viewModel.hasUnsavedChanges)
    }

    @Test("Dropping application bundles appends them")
    func dropImportsApplications() async throws {
        let mail = try makeApplicationBundle(
            name: "Mail",
            bundleIdentifier: "com.example.mail",
            displayName: "Example Mail"
        )
        defer {
            try? FileManager.default.removeItem(at: mail.deletingLastPathComponent())
        }

        let viewModel = SettingsViewModel(client: SettingsViewStoreClientSpy())
        await viewModel.load()

        let accepted = viewModel.addProtectedApplications(at: [mail])

        #expect(accepted)
        #expect(viewModel.draft.protectedApps.map(\.bundleIdentifier) == ["com.example.mail"])
        #expect(viewModel.draft.protectedApps.map(\.displayName) == ["Example Mail"])
        #expect(viewModel.applicationImportError == nil)
        #expect(viewModel.hasUnsavedChanges)
    }

    @Test("Dropping an application that is already protected does not change the draft")
    func dropSkipsDuplicateBundleIdentifier() async throws {
        let existing = ProtectedApplication(
            bundleIdentifier: "com.example.mail",
            displayName: "Mail"
        )
        let mail = try makeApplicationBundle(
            name: "Mail",
            bundleIdentifier: "COM.EXAMPLE.MAIL",
            displayName: "Other Mail"
        )
        defer {
            try? FileManager.default.removeItem(at: mail.deletingLastPathComponent())
        }

        let viewModel = SettingsViewModel(
            client: SettingsViewStoreClientSpy(
                settings: Settings(protectedApps: [existing])
            )
        )
        await viewModel.load()

        let accepted = viewModel.addProtectedApplications(at: [mail])

        #expect(accepted)
        #expect(viewModel.draft.protectedApps == [existing])
        #expect(viewModel.applicationImportError == nil)
        #expect(!viewModel.hasUnsavedChanges)
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

private func makeApplicationBundle(
    name: String,
    bundleIdentifier: String,
    displayName: String
) throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("dawn-protected-app-\(UUID().uuidString)", isDirectory: true)
    let contents = root
        .appendingPathComponent("\(name).app", isDirectory: true)
        .appendingPathComponent("Contents", isDirectory: true)
    try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)

    let info = [
        "CFBundleIdentifier": bundleIdentifier,
        "CFBundleName": name,
        "CFBundleDisplayName": displayName,
        "CFBundlePackageType": "APPL",
    ]
    let data = try PropertyListSerialization.data(
        fromPropertyList: info,
        format: .xml,
        options: 0
    )
    try data.write(to: contents.appendingPathComponent("Info.plist"))
    return contents.deletingLastPathComponent()
}
