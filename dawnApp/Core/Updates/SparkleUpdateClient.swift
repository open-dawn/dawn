//
//  SparkleUpdateClient.swift
//  dawn
//
//  Created by Rafael Venetikides on 30/10/26.
//

import Foundation
import Sparkle
import dawnLogging

@MainActor
final class SparkleUpdateClient: NSObject, AppUpdateClient {
    weak var delegate: (any AppUpdateClientDelegate)?

    private let hostBundle: Bundle
    private var canCheckObservation: NSKeyValueObservation?

    private var currentUpdate: AvailableAppUpdate?
    private var expectedDownloadLength: UInt64 = 0
    private var receivedDownloadLength: UInt64 = 0

    private var checkCancellation: (() -> Void)?
    private var downloadCancellation: (() -> Void)?

    private var updateChoice: CheckedContinuation<SPUUserUpdateChoice, Never>?

    private var relaunchChoice: CheckedContinuation<SPUUserUpdateChoice, Never>?

    private lazy var updater = SPUUpdater(
        hostBundle: hostBundle,
        applicationBundle: hostBundle,
        userDriver: self,
        delegate: nil
    )

    var canCheckForUpdates: Bool {
        updater.canCheckForUpdates
    }

    init(hostBundle: Bundle = .main) {
        self.hostBundle = hostBundle
        super.init()
    }

    func start() throws {
        try updater.start()

        canCheckObservation = updater.observe(
            \.canCheckForUpdates,
            options: [.initial, .new],
            changeHandler: { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    guard let self else {
                        return
                    }

                    delegate?.appUpdateClientCanCheckForUpdatesDidChange(self)
                }
            }
        )
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }

    func installAvailableUpdate() {
        guard let choice = updateChoice else {
            return
        }

        updateChoice = nil
        choice.resume(returning: .install)
    }

    func installAndRelaunch() {
        guard let choice = relaunchChoice else {
            return
        }

        relaunchChoice = nil
        choice.resume(returning: .install)
    }

    func cancelUpdate() {
        let checkCancellation = self.checkCancellation
        let downloadCancellation = self.downloadCancellation
        let updateChoice = self.updateChoice
        let relaunchChoice = self.relaunchChoice

        self.checkCancellation = nil
        self.downloadCancellation = nil
        self.updateChoice = nil
        self.relaunchChoice = nil

        checkCancellation?()
        downloadCancellation?()
        updateChoice?.resume(returning: .dismiss)
        relaunchChoice?.resume(returning: .dismiss)

        currentUpdate = nil
        delegate?.appUpdateClientDidCancel(self)
    }

    private func dismissPendingChoices() {
        let updateChoice = self.updateChoice
        let relaunchChoice = self.relaunchChoice

        self.updateChoice = nil
        self.relaunchChoice = nil
        checkCancellation = nil
        downloadCancellation = nil

        updateChoice?.resume(returning: .dismiss)
        relaunchChoice?.resume(returning: .dismiss)
    }
}

extension SparkleUpdateClient: SPUUserDriver {
    func show(_ request: SPUUpdatePermissionRequest) async -> SUUpdatePermissionResponse {
        SUUpdatePermissionResponse(automaticUpdateChecks: false, sendSystemProfile: false)
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        checkCancellation = cancellation
    }

    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState) async -> SPUUserUpdateChoice {
        checkCancellation = nil

        let update = AvailableAppUpdate(
            displayVersion: appcastItem.displayVersionString,
            buildVersion: appcastItem.versionString,
            releaseNotesURL: appcastItem.releaseNotesURL,
            informationURL: appcastItem.infoURL
        )

        currentUpdate = update
        delegate?.appUpdateClient(self, didFind: update)

        return await withCheckedContinuation { continuation in
            updateChoice = continuation
        }
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {
    }

    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error) {
        let description = String(describing: error)

        #log(
            "Failed to download update release notes: \(description, privacy: .private)",
            level: .warning,
            category: .appLifecycle
        )
    }

    func showUpdateNotFoundWithError(_ error: any Error) async {
        checkCancellation = nil
        currentUpdate = nil
        delegate?.appUpdateClientDidFindNoUpdate(self)
    }

    func showUpdaterError(_ error: any Error) async {
        checkCancellation = nil
        downloadCancellation = nil
        delegate?.appUpdateClient(self, didFailWithError: error)
    }

    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        downloadCancellation = cancellation
        expectedDownloadLength = 0
        receivedDownloadLength = 0

        guard let currentUpdate else {
            return
        }

        delegate?.appUpdateClient(self, didBeginDownloading: currentUpdate)
    }

    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        expectedDownloadLength = expectedContentLength
        receivedDownloadLength = 0
    }

    func showDownloadDidReceiveData(ofLength length: UInt64) {
        receivedDownloadLength += length

        let progress: AppUpdateProgress

        if expectedDownloadLength > 0 {
            let fraction = min(
                Double(receivedDownloadLength)
                    / Double(expectedDownloadLength),
                1
            )
            progress = .fraction(fraction)
        } else {
            progress = .indeterminate
        }

        delegate?.appUpdateClient(
            self,
            didReceiveDownloadProgress: progress
        )
    }

    func showDownloadDidStartExtractingUpdate() {
        downloadCancellation = nil
        delegate?.appUpdateClientDidBeginExtracting(self)
    }

    func showExtractionReceivedProgress(_ progress: Double) {
        delegate?.appUpdateClient(
            self,
            didReceiveExtractionProgress: .fraction(
                min(max(progress, 0), 1)
            )
        )
    }

    func showReadyToInstallAndRelaunch()
        async -> SPUUserUpdateChoice
    {
        delegate?.appUpdateClientDidBecomeReadyToInstall(self)

        return await withCheckedContinuation { continuation in
            relaunchChoice = continuation
        }
    }

    func showInstallingUpdate(
        withApplicationTerminated applicationTerminated: Bool,
        retryTerminatingApplication: @escaping () -> Void
    ) {
        delegate?.appUpdateClientDidBeginInstalling(self)
    }

    func showUpdateInstalledAndRelaunched(
        _ relaunched: Bool
    ) async {
    }

    func dismissUpdateInstallation() {
        dismissPendingChoices()
        currentUpdate = nil
    }
}
