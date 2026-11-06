import Foundation
import Observation
import libdawn

@Observable
@MainActor
final class SettingsViewStore: Listener {
    private let bus: any SettingsEventBus
    private var isStarted = false

    private(set) var settings = Settings()
    private(set) var isLoading = false
    private(set) var error: SettingsViewStoreError?

    init(bus: any SettingsEventBus) {
        self.bus = bus
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true

        bus.addListener(
            self,
            kinds: [.availableSettings]
        )
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        bus.removeListener(self)
    }

    func dismissError() {
        error = nil
    }

    func handle(_ event: Event, reply _: (@Sendable (Event) -> Void)?) {
        guard case let .availableSettings(payload) = event else {
            return
        }

        settings = payload.settings
        error = nil
        SettingsLoginItem.apply(launchAtLogin: payload.settings.launchAtLogin)
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await bus.ask(
                .getSettings(GetSettingsEvent()),
                timeout: .seconds(5)
            )

            switch response {
            case let .settingsFetched(payload):
                settings = payload.settings
                error = nil
                SettingsLoginItem.apply(launchAtLogin: payload.settings.launchAtLogin)

            case let .availableSettings(payload):
                settings = payload.settings
                error = nil
                SettingsLoginItem.apply(launchAtLogin: payload.settings.launchAtLogin)

            default:
                error = .unexpectedResponse(response.kind)
            }
        } catch {
            let storeError = SettingsViewStoreError(error)
            self.error = (storeError == .notConnected) ? nil : storeError
        }
    }

    func updateSettings(_ settings: Settings) async throws(SettingsViewStoreError) {
        do {
            let response = try await bus.ask(
                .updateSettings(UpdateSettingsEvent(settings: settings)),
                timeout: .seconds(5)
            )

            guard case let .settingsMutationAcknowledgement(acknowledgement) = response else {
                throw SettingsViewStoreError.unexpectedResponse(response.kind)
            }

            switch acknowledgement {
            case .success:
                self.settings = settings
                error = nil
                SettingsLoginItem.apply(launchAtLogin: settings.launchAtLogin)
            case let .failure(failure):
                throw SettingsViewStoreError.mutationRejected(failure)
            }
        } catch {
            let storeError = SettingsViewStoreError(error)
            self.error = storeError == .notConnected ? nil : storeError
            throw storeError
        }
    }
}
