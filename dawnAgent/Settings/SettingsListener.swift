import libdawn

@MainActor
protocol SettingsProviding {
    func getSettings() async -> Settings
    func updateSettings(_ settings: Settings) async throws
}

final class SettingsCoordinator: SettingsProviding {
    private let store: SettingsStore

    init(store: SettingsStore) {
        self.store = store
    }

    func getSettings() async -> Settings {
        let storeSnapshot = await store.snapshot()
        return storeSnapshot.generalSettings
    }

    func updateSettings(_ settings: Settings) async throws {
        try await store.updateSettings(settings)
    }
}

@MainActor
final class SettingsListener: Listener {
    private let settingsProvider: any SettingsProviding

    init(bus: EventBus, settingsProvider: any SettingsProviding) {
        self.settingsProvider = settingsProvider
        bus.addListener(self, kinds: [
            .getSettings,
            .updateSettings,
        ])
    }

    func handle(_ event: Event, reply: (@Sendable (Event) -> Void)?) {
        switch event {
        case .getSettings:
            Task { @MainActor in
                let settings = await settingsProvider.getSettings()
                reply?(.settingsFetched(SettingsFetchedEvent(settings: settings)))
            }

        case let .updateSettings(payload):
            handleUpdateSettings(payload, reply: reply)

        default:
            return
        }
    }

    private func handleUpdateSettings(_ payload: UpdateSettingsEvent, reply: (@Sendable (Event) -> Void)?) {
        guard let reply else { return }

        Task { @MainActor in
            do {
                try await settingsProvider.updateSettings(payload.settings)
                publishSettings()
                reply(.settingsMutationAcknowledgement(.success))
            } catch {
                reply(
                    .settingsMutationAcknowledgement(
                        .failure(failure: mutationFailure(from: error))
                    )
                )
            }
        }
    }

    private func publishSettings() {
        // PIN-160 Apply stored settings to app
    }

    private func mutationFailure(from error: Error) -> SettingsMutationAcknowledgement.Failure {
        if let error = error as? SettingsStoreError {
            return switch error {
            case .emptyApplicationDisplayName: .emptyApplicationDisplayName
            case .emptyApplicationBundleIdentifier: .emptyApplicationBundleIdentifier
            case let .duplicateApplication(bundleIdentifier): .duplicateApplication(bundleIdentifier: bundleIdentifier)
            case let .duplicateApplicationIdentifier(id): .duplicateApplicationIdentifier(id: id)
            default: .unexpected
            }
        }

        if error is SettingsRepositoryError {
            return .persistence
        }

        return .unexpected
    }
}
