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
    private let bus: EventBus
    private let settingsProvider: any SettingsProviding
    private let applicator: any SettingsApplying

    init(
        bus: EventBus,
        settingsProvider: any SettingsProviding,
        applicator: any SettingsApplying
    ) {
        self.bus = bus
        self.settingsProvider = settingsProvider
        self.applicator = applicator
        bus.addListener(self, kinds: [
            .getSettings,
            .updateSettings,
            .applySettings,
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

        case .applySettings:
            Task { @MainActor in
                let settings = await settingsProvider.getSettings()
                await applicator.applySettings(settings)
                bus.publish(.availableSettings(AvailableSettingsEvent(settings: settings)))
            }

        default:
            return
        }
    }

    private func handleUpdateSettings(_ payload: UpdateSettingsEvent, reply: (@Sendable (Event) -> Void)?) {
        guard let reply else { return }

        Task { @MainActor in
            do {
                try await settingsProvider.updateSettings(payload.settings)
                await applicator.applySettings(payload.settings)
                bus.publish(.availableSettings(AvailableSettingsEvent(settings: payload.settings)))
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
