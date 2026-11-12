//
//  AppUpdaterService.swift
//  dawn
//
//  Created by Rafael Venetikides on 30/10/26.
//

import Observation
import dawnLogging

@Observable
@MainActor
final class AppUpdaterService: AppUpdating {
    @ObservationIgnored
    private let client: any AppUpdateClient

    @ObservationIgnored
    private var isStarted = false

    @ObservationIgnored
    private var activeUpdate: AvailableAppUpdate?

    @ObservationIgnored
    private let componentCoordinator: any UpdateComponentCoordinating

    @ObservationIgnored
    private var componentsPreparedForInstallation = false

    @ObservationIgnored
    private var recoveryTask: Task<Void, Never>?

    private var clientCanCheckForUpdates = false

    private(set) var state: AppUpdateState = .idle

    var canCheckForUpdates: Bool {
        guard isStarted, clientCanCheckForUpdates else {
            return false
        }

        return switch state {
        case .idle, .updateUnavailable, .failed:
            true
        case .checking, .updateAvailable, .downloading, .extracting, .readyToInstall, .installing:
            false
        }
    }

    init(client: any AppUpdateClient, componentCoordinator: any UpdateComponentCoordinating) {
        self.client = client
        self.componentCoordinator = componentCoordinator
        clientCanCheckForUpdates = client.canCheckForUpdates
        client.delegate = self
    }

    func start() {
        guard !isStarted else {
            return
        }

        do {
            try client.start()
            isStarted = true
            clientCanCheckForUpdates = client.canCheckForUpdates
        } catch {
            let description = String(describing: error)

            #log("Failed to start updater: \(description, privacy: .private)", level: .error, category: .appLifecycle)

            state = .failed(reason: .updaterUnavailable)
        }
    }

    func checkForUpdates() {
        guard canCheckForUpdates else {
            return
        }

        activeUpdate = nil
        state = .checking
        client.checkForUpdates()
    }

    func installAvailableUpdate() {
        guard case let .updateAvailable(update) = state else {
            return
        }

        activeUpdate = update
        state = .downloading(update, progress: .indeterminate)
        client.installAvailableUpdate()
    }

    func installAndRelaunch() async {
        guard case let .readyToInstall(update) = state else {
            return
        }

        state = .installing(update)

        do {
            try await componentCoordinator.prepareForUpdate(update)

            componentsPreparedForInstallation = true
        } catch {
            let description = String(describing: error)

            #log(
                "Failed to prepare update components: \(description, privacy: .private)",
                level: .error,
                category: .appLifecycle
            )

            await recoverComponents(finalState: .failed(reason: .componentPreparationFailed))

            return
        }

        client.installAndRelaunch()
    }

    func cancelUpdate() {
        switch state {
        case .checking, .updateAvailable, .downloading, .extracting, .readyToInstall:
            client.cancelUpdate()
            activeUpdate = nil
            state = .idle

        case .idle, .updateUnavailable, .installing, .failed:
            return
        }
    }

    private func recoverComponents(finalState: AppUpdateState) async {
        do {
            try await componentCoordinator.recoverAfterUpdateFailure()

            state = finalState
        } catch {
            let description = String(describing: error)

            #log(
                "#Failed to recover update components: \(description, privacy: .private)",
                level: .error,
                category: .appLifecycle
            )

            state = .failed(reason: .componentRecoveryFailed)
        }

        activeUpdate = nil
        componentsPreparedForInstallation = false
    }

    private func scheduleComponentRecovery(finalState: AppUpdateState) {
        guard recoveryTask == nil else {
            return
        }

        recoveryTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            await recoverComponents(finalState: finalState)

            recoveryTask = nil
        }
    }
}

extension AppUpdaterService: AppUpdateClientDelegate {
    func appUpdateClientCanCheckForUpdatesDidChange(_ client: any AppUpdateClient) {
        clientCanCheckForUpdates = client.canCheckForUpdates
    }

    func appUpdateClient(_ client: any AppUpdateClient, didFind update: AvailableAppUpdate) {
        activeUpdate = update
        state = .updateAvailable(update)
    }

    func appUpdateClient(_ client: any AppUpdateClient, didFindNoUpdate reason: AppUpdateUnavailabilityReason) {
        activeUpdate = nil
        state = .updateUnavailable(reason: reason)
    }

    func appUpdateClient(_ client: any AppUpdateClient, didBeginDownloading update: AvailableAppUpdate) {
        activeUpdate = update
        state = .downloading(update, progress: .indeterminate)
    }

    func appUpdateClient(_ client: any AppUpdateClient, didReceiveDownloadProgress progress: AppUpdateProgress) {
        guard let activeUpdate else {
            return
        }

        state = .downloading(activeUpdate, progress: progress)
    }

    func appUpdateClientDidBeginExtracting(_ client: any AppUpdateClient) {
        guard let activeUpdate else {
            return
        }

        state = .extracting(activeUpdate, progress: .indeterminate)
    }

    func appUpdateClient(_ client: any AppUpdateClient, didReceiveExtractionProgress progress: AppUpdateProgress) {
        guard let activeUpdate else {
            return
        }

        state = .extracting(activeUpdate, progress: progress)
    }

    func appUpdateClientDidBecomeReadyToInstall(_ client: any AppUpdateClient) {
        guard let activeUpdate else {
            return
        }

        state = .readyToInstall(activeUpdate)
    }

    func appUpdateClientDidBeginInstalling(_ client: any AppUpdateClient) {
        guard let activeUpdate else {
            return
        }

        state = .installing(activeUpdate)
    }

    func appUpdateClientDidCancel(_ client: any AppUpdateClient) {
        guard componentsPreparedForInstallation else {
            activeUpdate = nil
            state = .idle
            return
        }

        scheduleComponentRecovery(finalState: .idle)
    }

    func appUpdateClient(_ client: any AppUpdateClient, didFailWith reason: AppUpdateFailureReason) {
        guard componentsPreparedForInstallation else {
            activeUpdate = nil
            state = .failed(reason: reason)
            return
        }

        scheduleComponentRecovery(finalState: .failed(reason: reason))
    }
}
