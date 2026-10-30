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

    private var clientCanCheckForUpdates = false

    private(set) var state: AppUpdateState = .idle

    var canCheckForUpdates: Bool {
        guard isStarted, clientCanCheckForUpdates else {
            return false
        }

        switch state {
        case .idle, .upToDate, .failed:
            return true
        case .checking, .updateAvailable, .downloading, .extracting, .readyToInstall, .installing:
            return false
        }
    }

    init(client: any AppUpdateClient) {
        self.client = client
        self.clientCanCheckForUpdates = client.canCheckForUpdates
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

            state = .failed(message: "Updates are temporarily unavailable")
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

    func installAndRelaunch() {
        guard case let .readyToInstall(update) = state else {
            return
        }

        state = .installing(update)
        client.installAndRelaunch()
    }

    func cancelUpdate() {
        switch state {
        case .checking, .updateAvailable, .downloading, .extracting, .readyToInstall:
            client.cancelUpdate()
            activeUpdate = nil
            state = .idle

        case .idle, .upToDate, .installing, .failed:
            return
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

    func appUpdateClientDidFindNoUpdate(_ client: any AppUpdateClient) {
        activeUpdate = nil
        state = .upToDate
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
        activeUpdate = nil
        state = .idle
    }

    func appUpdateClient(_ client: any AppUpdateClient, didFailWithError error: any Error) {
        let description = String(describing: error)

        #log("Updater operation failed: \(description, privacy: .private)", level: .error, category: .appLifecycle)

        activeUpdate = nil
        state = .failed(message: "The update couldn't be completed. Please try again.")
    }
}
