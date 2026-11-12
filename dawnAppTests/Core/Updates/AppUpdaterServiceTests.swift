//
//  AppUpdaterServiceTests.swift
//  dawn
//
//  Created by Rafael Venetikides on 30/10/26.
//

import Foundation
import Testing

@testable import dawnApp

@MainActor
@Suite("App updater service")
struct AppUpdaterServiceTests {
    private var update: AvailableAppUpdate {
        AvailableAppUpdate(
            displayVersion: "1.2.0",
            buildVersion: "12",
            releaseNotesURL: URL(
                string: "https://update.opendawn.app/releases/1.2.0"
            ),
            informationURL: nil
        )
    }

    @Test("Start initializes the client once")
    func startIsIdempotent() {
        let client = FakeAppUpdateClient()
        let service = AppUpdaterService(client: client, componentCoordinator: FakeUpdateComponentCoordinator())

        #expect(!service.canCheckForUpdates)

        service.start()
        service.start()

        #expect(client.startCallCount == 1)
        #expect(service.canCheckForUpdates)
    }

    @Test("Repeated checks cannot start concurrently")
    func concurrentChecksArePrevented() {
        let client = FakeAppUpdateClient()
        let service = AppUpdaterService(client: client, componentCoordinator: FakeUpdateComponentCoordinator())

        service.start()
        service.checkForUpdates()
        service.checkForUpdates()

        #expect(service.state == .checking)
        #expect(client.checkCallCount == 1)
        #expect(!service.canCheckForUpdates)
    }

    @Test("Found update is exposed and can begin downloading")
    func availableUpdateCanDownload() {
        let client = FakeAppUpdateClient()
        let service = AppUpdaterService(client: client, componentCoordinator: FakeUpdateComponentCoordinator())

        service.start()
        service.checkForUpdates()
        client.sendFound(update)

        #expect(service.state == .updateAvailable(update))

        service.installAvailableUpdate()
        service.installAvailableUpdate()

        #expect(
            service.state
                == .downloading(
                    update,
                    progress: .indeterminate
                )
        )
        #expect(client.installCallCount == 1)
    }

    @Test(
        "No update exposes its unavailability reason",
        arguments: [
            AppUpdateUnavailabilityReason.currentVersionIsLatest,
            AppUpdateUnavailabilityReason.currentVersionIsNewer,
            AppUpdateUnavailabilityReason.systemIsTooOld,
            AppUpdateUnavailabilityReason.systemIsTooNew,
            AppUpdateUnavailabilityReason.unsupportedHardware,
            AppUpdateUnavailabilityReason.unknown,
        ]
    )
    func noUpdateFound(reason: AppUpdateUnavailabilityReason) {
        let client = FakeAppUpdateClient()
        let service = AppUpdaterService(client: client, componentCoordinator: FakeUpdateComponentCoordinator())

        service.start()
        service.checkForUpdates()
        client.sendNoUpdate(reason)

        #expect(
            service.state == .updateUnavailable(reason: reason)
        )
        #expect(service.canCheckForUpdates)
    }

    @Test("Startup failure is recoverable")
    func startupFailure() {
        let client = FakeAppUpdateClient()
        client.startError = TestError.expected

        let service = AppUpdaterService(client: client, componentCoordinator: FakeUpdateComponentCoordinator())
        service.start()

        #expect(
            service.state
                == .failed(
                    reason: .updaterUnavailable
                )
        )
        #expect(!service.canCheckForUpdates)
    }

    @Test("Update progresses through download and installation")
    func installationProgress() async throws {
        let client = FakeAppUpdateClient()
        let service = AppUpdaterService(client: client, componentCoordinator: FakeUpdateComponentCoordinator())

        service.start()
        service.checkForUpdates()
        client.sendFound(update)
        service.installAvailableUpdate()

        client.sendDownloadProgress(.fraction(0.25))
        #expect(
            service.state
                == .downloading(
                    update,
                    progress: .fraction(0.25)
                )
        )

        client.sendExtractionStarted()
        client.sendExtractionProgress(.fraction(0.75))
        #expect(
            service.state
                == .extracting(
                    update,
                    progress: .fraction(0.75)
                )
        )

        client.sendReadyToInstall()
        #expect(service.state == .readyToInstall(update))

        await service.installAndRelaunch()

        #expect(service.state == .installing(update))
        #expect(client.relaunchCallCount == 1)
    }

    @Test("Cancellation returns to idle")
    func cancellation() {
        let client = FakeAppUpdateClient()
        let service = AppUpdaterService(client: client, componentCoordinator: FakeUpdateComponentCoordinator())

        service.start()
        service.checkForUpdates()
        service.cancelUpdate()

        #expect(service.state == .idle)
        #expect(client.cancelCallCount == 1)
    }

    @Test("Client availability is propagated")
    func clientAvailability() {
        let client = FakeAppUpdateClient()
        let service = AppUpdaterService(client: client, componentCoordinator: FakeUpdateComponentCoordinator())

        service.start()
        #expect(service.canCheckForUpdates)

        client.canCheckForUpdates = false
        #expect(!service.canCheckForUpdates)

        client.canCheckForUpdates = true
        #expect(service.canCheckForUpdates)
    }

    @Test(
        "Updater failures expose their reason and permit retrying",
        arguments: [
            AppUpdateFailureReason.updaterUnavailable,
            AppUpdateFailureReason.networkUnavailable,
            AppUpdateFailureReason.invalidFeed,
            AppUpdateFailureReason.invalidMetadata,
            AppUpdateFailureReason.invalidUpdate,
            AppUpdateFailureReason.installationFailed,
            AppUpdateFailureReason.unknown,
        ]
    )
    func updaterFailure(reason: AppUpdateFailureReason) {
        let client = FakeAppUpdateClient()
        let service = AppUpdaterService(client: client, componentCoordinator: FakeUpdateComponentCoordinator())

        service.start()
        service.checkForUpdates()
        client.sendFailure(reason)

        #expect(service.state == .failed(reason: reason))
        #expect(service.canCheckForUpdates)
    }

    @Test("Network failure during download permits retrying")
    func networkFailureDuringDownload() async throws {
        let client = FakeAppUpdateClient()
        let service = AppUpdaterService(client: client, componentCoordinator: FakeUpdateComponentCoordinator())

        service.start()
        service.checkForUpdates()
        client.sendFound(update)
        service.installAvailableUpdate()

        try #require(service.state == .downloading(update, progress: .indeterminate))

        client.sendFailure(.networkUnavailable)

        #expect(service.state == .failed(reason: .networkUnavailable))
        #expect(service.canCheckForUpdates)
    }

    @Test("Cancellation during download returns to idle")
    func cancellationDuringDownload() {
        let client = FakeAppUpdateClient()
        let service = AppUpdaterService(client: client, componentCoordinator: FakeUpdateComponentCoordinator())

        service.start()
        service.checkForUpdates()
        client.sendFound(update)
        service.installAvailableUpdate()
        service.cancelUpdate()

        #expect(service.state == .idle)
        #expect(service.canCheckForUpdates)
        #expect(client.cancelCallCount == 1)
    }

    @Test("Cancellation during installation returns to idle")
    func cancellationDuringInstallation() async throws {
        let client = FakeAppUpdateClient()
        let service = AppUpdaterService(client: client, componentCoordinator: FakeUpdateComponentCoordinator())

        service.start()
        service.checkForUpdates()
        client.sendFound(update)
        service.installAvailableUpdate()
        client.sendReadyToInstall()
        await service.installAndRelaunch()

        #expect(service.state == .installing(update))

        client.sendCancellation()

        try await waitUntil {
            service.state == .idle
        }

        #expect(service.state == .idle)
        #expect(service.canCheckForUpdates)
    }

    @Test("Component preparation failure does not start Sparkle")
    func preparationFailureDoesNotInstall() async {
        let client = FakeAppUpdateClient()
        let coordinator = FakeUpdateComponentCoordinator()
        coordinator.preparationError = TestError.expected

        let service = AppUpdaterService(
            client: client,
            componentCoordinator: coordinator
        )

        service.start()
        service.checkForUpdates()
        client.sendFound(update)
        service.installAvailableUpdate()
        client.sendReadyToInstall()

        await service.installAndRelaunch()

        #expect(coordinator.preparedUpdates == [update])
        #expect(client.relaunchCallCount == 0)
        #expect(
            service.state
                == .failed(
                    reason: .componentPreparationFailed
                )
        )
        #expect(coordinator.recoveryCallCount == 1)
    }

    @Test("Installation failure recovers prepared components")
    func installationFailureRecoversComponents() async throws {
        let client = FakeAppUpdateClient()
        let coordinator = FakeUpdateComponentCoordinator()

        let service = AppUpdaterService(
            client: client,
            componentCoordinator: coordinator
        )

        service.start()
        service.checkForUpdates()
        client.sendFound(update)
        service.installAvailableUpdate()
        client.sendReadyToInstall()

        await service.installAndRelaunch()

        client.sendFailure(.installationFailed)

        try await waitUntil {
            coordinator.recoveryCallCount == 1
                && service.state
                    == .failed(reason: .installationFailed)
        }

        #expect(client.relaunchCallCount == 1)
    }

    @Test("Installation cancellation recovers prepared components")
    func installationCancellationRecoversComponents() async throws {
        let client = FakeAppUpdateClient()
        let coordinator = FakeUpdateComponentCoordinator()

        let service = AppUpdaterService(
            client: client,
            componentCoordinator: coordinator
        )

        service.start()
        service.checkForUpdates()
        client.sendFound(update)
        service.installAvailableUpdate()
        client.sendReadyToInstall()

        await service.installAndRelaunch()

        client.sendCancellation()

        try await waitUntil {
            coordinator.recoveryCallCount == 1
                && service.state == .idle
        }
    }

    @Test("Recovery failure exposes component recovery failure")
    func recoveryFailureIsExposed() async throws {
        let client = FakeAppUpdateClient()
        let coordinator = FakeUpdateComponentCoordinator()
        coordinator.recoveryError = TestError.expected

        let service = AppUpdaterService(
            client: client,
            componentCoordinator: coordinator
        )

        service.start()
        service.checkForUpdates()
        client.sendFound(update)
        service.installAvailableUpdate()
        client.sendReadyToInstall()

        await service.installAndRelaunch()
        client.sendFailure(.installationFailed)

        try await waitUntil {
            service.state
                == .failed(
                    reason: .componentRecoveryFailed
                )
        }
    }

}

@MainActor
private final class FakeAppUpdateClient: AppUpdateClient {
    weak var delegate: (any AppUpdateClientDelegate)?

    var startError: (any Error)?

    var canCheckForUpdates = true {
        didSet {
            delegate?.appUpdateClientCanCheckForUpdatesDidChange(self)
        }
    }

    private(set) var startCallCount = 0
    private(set) var checkCallCount = 0
    private(set) var installCallCount = 0
    private(set) var relaunchCallCount = 0
    private(set) var cancelCallCount = 0

    func start() throws {
        startCallCount += 1

        if let startError {
            throw startError
        }
    }

    func checkForUpdates() {
        checkCallCount += 1
    }

    func installAvailableUpdate() {
        installCallCount += 1
    }

    func installAndRelaunch() {
        relaunchCallCount += 1
    }

    func cancelUpdate() {
        cancelCallCount += 1
    }

    func sendFound(_ update: AvailableAppUpdate) {
        delegate?.appUpdateClient(self, didFind: update)
    }

    func sendNoUpdate(_ reason: AppUpdateUnavailabilityReason) {
        delegate?.appUpdateClient(
            self,
            didFindNoUpdate: reason
        )
    }

    func sendDownloadProgress(_ progress: AppUpdateProgress) {
        delegate?.appUpdateClient(self, didReceiveDownloadProgress: progress)
    }

    func sendExtractionStarted() {
        delegate?.appUpdateClientDidBeginExtracting(self)
    }

    func sendExtractionProgress(_ progress: AppUpdateProgress) {
        delegate?.appUpdateClient(
            self,
            didReceiveExtractionProgress: progress
        )
    }

    func sendReadyToInstall() {
        delegate?.appUpdateClientDidBecomeReadyToInstall(self)
    }

    func sendFailure(_ reason: AppUpdateFailureReason) {
        delegate?.appUpdateClient(self, didFailWith: reason)
    }

    func sendCancellation() {
        delegate?.appUpdateClientDidCancel(self)
    }
}

@MainActor
private final class FakeUpdateComponentCoordinator:
    UpdateComponentCoordinating
{
    var preparationError: Error?
    var recoveryError: Error?

    private(set) var preparedUpdates: [AvailableAppUpdate] = []
    private(set) var recoveryCallCount = 0

    func prepareForUpdate(
        _ update: AvailableAppUpdate
    ) async throws {
        preparedUpdates.append(update)

        if let preparationError {
            throw preparationError
        }
    }

    func recoverAfterUpdateFailure() async throws {
        recoveryCallCount += 1

        if let recoveryError {
            throw recoveryError
        }
    }

    func reconcileAfterUpdate(expectedBuild: String) async throws {
    }
}

@MainActor
private func waitUntil(
    _ condition: @MainActor () -> Bool
) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now + .seconds(1)

    while !condition() {
        guard clock.now < deadline else {
            throw TestError.timeout
        }

        await Task.yield()
    }
}

private enum TestError: Error {
    case expected
    case timeout
}
