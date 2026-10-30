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
        let service = AppUpdaterService(client: client)

        #expect(!service.canCheckForUpdates)

        service.start()
        service.start()

        #expect(client.startCallCount == 1)
        #expect(service.canCheckForUpdates)
    }

    @Test("Repeated checks cannot start concurrently")
    func concurrentChecksArePrevented() {
        let client = FakeAppUpdateClient()
        let service = AppUpdaterService(client: client)

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
        let service = AppUpdaterService(client: client)

        service.start()
        service.checkForUpdates()
        client.sendFound(update)

        #expect(service.state == .updateAvailable(update))

        service.installAvailableUpdate()
        service.installAvailableUpdate()

        #expect(
            service.state == .downloading(
                update,
                progress: .indeterminate
            )
        )
        #expect(client.installCallCount == 1)
    }

    @Test("No update produces the up-to-date result")
    func noUpdateFound() {
        let client = FakeAppUpdateClient()
        let service = AppUpdaterService(client: client)

        service.start()
        service.checkForUpdates()
        client.sendNoUpdate()

        #expect(service.state == .upToDate)
        #expect(service.canCheckForUpdates)
    }

    @Test("Startup failure is recoverable")
    func startupFailure() {
        let client = FakeAppUpdateClient()
        client.startError = TestError.expected

        let service = AppUpdaterService(client: client)
        service.start()

        #expect(
            service.state == .failed(
                message: "Updates are temporarily unavailable"
            )
        )
        #expect(!service.canCheckForUpdates)
    }

    @Test("Update progresses through download and installation")
    func installationProgress() {
        let client = FakeAppUpdateClient()
        let service = AppUpdaterService(client: client)

        service.start()
        service.checkForUpdates()
        client.sendFound(update)
        service.installAvailableUpdate()

        client.sendDownloadProgress(.fraction(0.25))
        #expect(
            service.state == .downloading(
                update,
                progress: .fraction(0.25)
            )
        )

        client.sendExtractionStarted()
        client.sendExtractionProgress(.fraction(0.75))
        #expect(
            service.state == .extracting(
                update,
                progress: .fraction(0.75)
            )
        )

        client.sendReadyToInstall()
        #expect(service.state == .readyToInstall(update))

        service.installAndRelaunch()

        #expect(service.state == .installing(update))
        #expect(client.relaunchCallCount == 1)
    }

    @Test("Cancellation returns to idle")
    func cancellation() {
        let client = FakeAppUpdateClient()
        let service = AppUpdaterService(client: client)

        service.start()
        service.checkForUpdates()
        service.cancelUpdate()

        #expect(service.state == .idle)
        #expect(client.cancelCallCount == 1)
    }

    @Test("Client availability is propagated")
    func clientAvailability() {
        let client = FakeAppUpdateClient()
        let service = AppUpdaterService(client: client)

        service.start()
        #expect(service.canCheckForUpdates)

        client.canCheckForUpdates = false
        #expect(!service.canCheckForUpdates)

        client.canCheckForUpdates = true
        #expect(service.canCheckForUpdates)
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

    func sendNoUpdate() {
        delegate?.appUpdateClientDidFindNoUpdate(self)
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

    func sendFailure(_ error: any Error) {
        delegate?.appUpdateClient(self, didFailWithError: error)
    }
}

private enum TestError: Error {
    case expected
}
