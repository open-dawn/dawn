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
    private enum DiagnosticStage: String {
        case check
        case download
        case verification
        case installation
    }

    private var diagnosticStage: DiagnosticStage = .check

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
        diagnosticStage = .check
        updater.checkForUpdates()
    }

    func installAvailableUpdate() {
        guard let choice = updateChoice else {
            return
        }

        diagnosticStage = .download
        updateChoice = nil
        choice.resume(returning: .install)
    }

    func installAndRelaunch() {
        guard let choice = relaunchChoice else {
            return
        }

        diagnosticStage = .installation
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

    static func unavailabilityReason(from error: any Error) -> AppUpdateUnavailabilityReason {
        let nsError = error as NSError

        guard let value = nsError.userInfo[SPUNoUpdateFoundReasonKey] as? NSNumber,
            let reason = SPUNoUpdateFoundReason(rawValue: value.int32Value)
        else {
            return .unknown
        }

        switch reason {
        case .onLatestVersion:
            return .currentVersionIsLatest
        case .onNewerThanLatestVersion:
            return .currentVersionIsNewer
        case .systemIsTooOld:
            return .systemIsTooOld
        case .systemIsTooNew:
            return .systemIsTooNew
        case .hardwareDoesNotSupportARM64:
            return .unsupportedHardware
        case .unknown:
            return .unknown
        @unknown default:
            return .unknown
        }
    }

    static func failureReason(from error: any Error) -> AppUpdateFailureReason {
        let nsError = error as NSError

        if containsNetworkError(nsError) {
            return .networkUnavailable
        }

        guard nsError.domain == SUSparkleErrorDomain,
            let rawValue = Int32(exactly: nsError.code),
            let sparkleError = SUError(rawValue: rawValue)
        else {
            return .unknown
        }

        switch sparkleError {
        case .insecureFeedURLError, .invalidFeedURLError, .appcastParseError:
            return .invalidFeed

        case .invalidHostVersionError, .appcastError:
            return .invalidMetadata

        case .noPublicDSAFoundError, .insufficientSigningError, .invalidUpdaterError, .invalidHostBundleIdentifierError:
            return .updaterUnavailable

        case .unarchivingError, .signatureError, .validationError, .notValidUpdateError:
            return .invalidUpdate

        case .fileCopyFailure, .authenticationFailure, .missingUpdateError, .missingInstallerToolError, .relaunchError,
            .installationError, .downgradeError, .agentInvalidationError, .installationWriteNoPermissionError:
            return .installationFailed

        default:
            return .unknown
        }
    }

    private static func containsNetworkError(_ error: NSError) -> Bool {
        var currentError: NSError? = error

        var depth = 0
        while depth < 8, let candidate = currentError {
            if candidate.domain == NSURLErrorDomain {
                return true
            }

            currentError = candidate.userInfo[NSUnderlyingErrorKey] as? NSError
            depth += 1
        }

        return false
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

        delegate?.appUpdateClient(self, didFindNoUpdate: Self.unavailabilityReason(from: error))
    }

    func showUpdaterError(_ error: any Error) async {
        checkCancellation = nil
        downloadCancellation = nil
        currentUpdate = nil

        let nsError = error as NSError
        let stage = diagnosticStage.rawValue
        let reason = Self.failureReason(from: error)

        #log(
            """
            Updater \(stage, privacy: .public) failed \
            (domain: \(nsError.domain, privacy: .public), \
            code: \(nsError.code, privacy: .public))
            """,
            level: .error,
            category: .appLifecycle
        )

        delegate?.appUpdateClient(self, didFailWith: Self.failureReason(from: error))
    }

    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        diagnosticStage = .download
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
        diagnosticStage = .verification
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

    func showReadyToInstallAndRelaunch() async -> SPUUserUpdateChoice {
        delegate?.appUpdateClientDidBecomeReadyToInstall(self)

        return await withCheckedContinuation { continuation in
            relaunchChoice = continuation
        }
    }

    func showInstallingUpdate(
        withApplicationTerminated applicationTerminated: Bool,
        retryTerminatingApplication: @escaping () -> Void
    ) {
        diagnosticStage = .installation
        delegate?.appUpdateClientDidBeginInstalling(self)
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool) async {
        currentUpdate = nil
    }

    func dismissUpdateInstallation() {
        let hadActiveUpdate = currentUpdate != nil

        dismissPendingChoices()
        currentUpdate = nil

        if hadActiveUpdate {
            delegate?.appUpdateClientDidCancel(self)
        }
    }
}
