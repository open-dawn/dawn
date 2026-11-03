//
//  AppUpdateClient.swift
//  dawn
//
//  Created by Rafael Venetikides on 30/10/26.
//

import Foundation

@MainActor
protocol AppUpdateClientDelegate: AnyObject {
    func appUpdateClientCanCheckForUpdatesDidChange(_ client: any AppUpdateClient)

    func appUpdateClient(
        _ client: any AppUpdateClient,
        didFind update: AvailableAppUpdate
    )

    func appUpdateClientDidFindNoUpdate(
        _ client: any AppUpdateClient
    )

    func appUpdateClient(
        _ client: any AppUpdateClient,
        didBeginDownloading update: AvailableAppUpdate
    )

    func appUpdateClient(
        _ client: any AppUpdateClient,
        didReceiveDownloadProgress progress: AppUpdateProgress
    )

    func appUpdateClientDidBeginExtracting(
        _ client: any AppUpdateClient
    )

    func appUpdateClient(
        _ client: any AppUpdateClient,
        didReceiveExtractionProgress progress: AppUpdateProgress
    )

    func appUpdateClientDidBecomeReadyToInstall(
        _ client: any AppUpdateClient
    )

    func appUpdateClientDidBeginInstalling(
        _ client: any AppUpdateClient
    )

    func appUpdateClientDidCancel(
        _ client: any AppUpdateClient
    )

    func appUpdateClient(
        _ client: any AppUpdateClient,
        didFailWithError error: any Error
    )
}

@MainActor
protocol AppUpdateClient: AnyObject {
    var delegate: (any AppUpdateClientDelegate)? { get set }
    var canCheckForUpdates: Bool { get }

    func start() throws
    func checkForUpdates()
    func installAvailableUpdate()
    func installAndRelaunch()
    func cancelUpdate()
}
