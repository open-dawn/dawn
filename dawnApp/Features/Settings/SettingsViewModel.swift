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
    private(set) var applicationImportError: ApplicationSelectionError?
    private(set) var isLoading = false

    private var baseline = Settings()
    private let client: any SettingsViewStoreClient

    var hasUnsavedChanges: Bool {
        draft != baseline
    }

    init(client: any SettingsViewStoreClient) {
        self.client = client
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

    func dismissApplicationImportError() {
        applicationImportError = nil
    }

    func removeProtectedApp(id: UUID) {
        draft.protectedApps.removeAll { $0.id == id }
    }

    @discardableResult
    func addProtectedApplications(at urls: [URL]) -> Bool {
        applicationImportError = nil

        var imported: [ProtectedApplication] = []
        var sawValidApplication = false
        var firstError: ApplicationSelectionError?

        for url in urls {
            do {
                let application = try WorkspaceApplication.imported(from: url)
                sawValidApplication = true
                let bundleIdentifier = normalizedBundleIdentifier(application.bundleIdentifier)
                let alreadyListed = draft.protectedApps.contains {
                    normalizedBundleIdentifier($0.bundleIdentifier) == bundleIdentifier
                } || imported.contains {
                    normalizedBundleIdentifier($0.bundleIdentifier) == bundleIdentifier
                }
                if !alreadyListed {
                    imported.append(
                        ProtectedApplication(
                            bundleIdentifier: application.bundleIdentifier,
                            displayName: application.displayName
                        )
                    )
                }
            } catch let error as ApplicationSelectionError {
                if firstError == nil {
                    firstError = error
                }
            } catch {
                if firstError == nil {
                    firstError = .unknown
                }
            }
        }

        applicationImportError = firstError

        if !imported.isEmpty {
            draft.protectedApps.append(contentsOf: imported)
        }

        return sawValidApplication
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

    private func normalizedBundleIdentifier(_ bundleIdentifier: String) -> String {
        bundleIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
