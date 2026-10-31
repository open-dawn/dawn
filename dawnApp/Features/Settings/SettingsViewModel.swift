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

    private let client: any SettingsViewStoreClient
    private let applicationSelector: any ApplicationSelecting

    init(
        client: any SettingsViewStoreClient,
        applicationSelector: any ApplicationSelecting = SystemApplicationSelector()
    ) {
        self.client = client
        self.applicationSelector = applicationSelector
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        await client.refresh()

        if client.error != nil {
            let loadError = ViewModelError.loadFailed
            error = loadError
            errorMessage = loadError.errorDescription
            return
        }

        draft = client.settings
        error = nil
        errorMessage = nil
        applicationSelectionError = nil
    }

    func setSettings() async {
        do {
            try await client.updateSettings(draft)
            error = nil
            errorMessage = nil
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
        guard !isLoading else {
            return
        }

        isLoading = true
        applicationSelectionError = nil
        defer { isLoading = false }

        do {
            guard let application = try await applicationSelector.selectApplication() else {
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

    func removeProtectedApp(id: UUID) {
        draft.protectedApps.removeAll { $0.id == id }
    }
}
