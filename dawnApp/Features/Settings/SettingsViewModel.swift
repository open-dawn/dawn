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
    private var persistTask: Task<Void, Never>?

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

    func updateDraft(_ mutate: (inout Settings) -> Void) {
        var updated = draft
        mutate(&updated)
        guard updated != draft else {
            return
        }

        draft = updated
        schedulePersist()
    }

    func setSettings() async {
        await persistDraft()
    }

    func flushPendingPersistence() async {
        await persistTask?.value
    }

    func resetSettingsToDefaults() {
        updateDraft { draft in
            draft = Settings()
        }
    }

    func dismissApplicationImportError() {
        applicationImportError = nil
    }

    func removeProtectedApp(id: UUID) {
        updateDraft { draft in
            draft.protectedApps.removeAll { $0.id == id }
        }
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
            updateDraft { draft in
                draft.protectedApps.append(contentsOf: imported)
            }
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

        updateDraft { draft in
            draft.protectedApps = merged
        }
    }

    private func schedulePersist() {
        persistTask?.cancel()
        persistTask = Task { [weak self] in
            await self?.persistDraft()
        }
    }

    private func persistDraft() async {
        guard draft != baseline else {
            return
        }

        let snapshot = draft

        do {
            try await client.updateSettings(snapshot)
            if draft == snapshot {
                baseline = snapshot
            }
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

    private func normalizedBundleIdentifier(_ bundleIdentifier: String) -> String {
        bundleIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
