import Foundation
import Observation
import libdawn

@MainActor
protocol SettingsViewStoreClient: AnyObject {
    var settings: Settings { get }
    var error: SettingsViewStoreError? { get }

    func refresh() async
    func updateSettings(_ settings: Settings) async throws(SettingsViewStoreError)
}

extension SettingsViewStore: SettingsViewStoreClient {}

@Observable
@MainActor
final class SettingsViewModel {
    var draft = Settings()

    private(set) var error: ViewModelError?
    private(set) var errorMessage: String?
    private(set) var applicationSelectionError: ApplicationSelectionError?
    private(set) var isLoading = false

    private var baseline = Settings()
    private let client: any SettingsViewStoreClient
    private let applicationSelector: any ApplicationSelecting
    private let runningApplicationSelector: any ApplicationSelecting

    var hasUnsavedChanges: Bool {
        draft != baseline
    }

    init(
        client: any SettingsViewStoreClient,
        applicationSelector: any ApplicationSelecting = SystemApplicationSelector(),
        runningApplicationSelector: any ApplicationSelecting = SystemRunningApplicationSelector()
    ) {
        self.client = client
        self.applicationSelector = applicationSelector
        self.runningApplicationSelector = runningApplicationSelector
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        await client.refresh()

        if client.error == .notConnected {
            return
        }

        if client.error != nil {
            let loadError = ViewModelError.loadFailed
            error = loadError
            errorMessage = loadError.errorDescription
            return
        }

        draft = client.settings
        baseline = client.settings
        error = nil
        errorMessage = nil
        applicationSelectionError = nil
    }

    func setSettings() async {
        do {
            try await client.updateSettings(draft)
            baseline = draft
            error = nil
            errorMessage = nil
        } catch SettingsViewStoreError.notConnected {
            return
        } catch {
            let persistenceError = ViewModelError.persistenceFailed
            self.error = persistenceError
            errorMessage = persistenceError.errorDescription
        }
    }

    func resetSettingsToDefaults() {
        draft = Settings()
    }

    func addProtectedApp() async {
        await addProtectedApp(using: applicationSelector)
    }

    func addProtectedAppFromRunning() async {
        await addProtectedApp(using: runningApplicationSelector)
    }

    func removeProtectedApp(id: UUID) {
        draft.protectedApps.removeAll { $0.id == id }
    }

    func applyProtectedApplicationSelection(_ selected: [ProtectedApplication]) {
        var merged: [ProtectedApplication] = []
        var consumedBundleIdentifiers = Set<String>()

        for application in draft.protectedApps {
            let bundleIdentifier = normalizedBundleIdentifier(application.bundleIdentifier)
            guard selected.contains(where: {
                normalizedBundleIdentifier($0.bundleIdentifier) == bundleIdentifier
            }) else {
                continue
            }

            guard consumedBundleIdentifiers.insert(bundleIdentifier).inserted else {
                continue
            }

            merged.append(application)
        }

        for application in selected {
            let bundleIdentifier = normalizedBundleIdentifier(application.bundleIdentifier)
            guard consumedBundleIdentifiers.insert(bundleIdentifier).inserted else {
                continue
            }

            merged.append(application)
        }

        guard merged != draft.protectedApps else {
            return
        }

        draft.protectedApps = merged
    }

    private func addProtectedApp(using selector: any ApplicationSelecting) async {
        guard !isLoading else {
            return
        }

        isLoading = true
        applicationSelectionError = nil
        defer { isLoading = false }

        do {
            guard let application = try await selector.selectApplication() else {
                return
            }

            let alreadyProtected = draft.protectedApps.contains {
                $0.bundleIdentifier.caseInsensitiveCompare(application.bundleIdentifier) == .orderedSame
            }

            guard !alreadyProtected else {
                return
            }

            draft.protectedApps.append(
                ProtectedApplication(
                    bundleIdentifier: application.bundleIdentifier,
                    displayName: application.displayName
                )
            )
        } catch let error as ApplicationSelectionError {
            applicationSelectionError = error
        } catch {
            applicationSelectionError = .unknown
        }
    }

    private func normalizedBundleIdentifier(_ bundleIdentifier: String) -> String {
        bundleIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
