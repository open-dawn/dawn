//
//  AppUpdateState.swift
//  dawn
//
//  Created by Rafael Venetikides on 30/10/26.
//

import Foundation

struct AvailableAppUpdate: Equatable, Sendable {
    let displayVersion: String
    let buildVersion: String
    let releaseNotesURL: URL?
    let informationURL: URL?
}

enum AppUpdateProgress: Equatable, Sendable {
    case indeterminate
    case fraction(Double)
}

enum AppUpdateUnavailabilityReason: Equatable, Sendable {
    case currentVersionIsLatest
    case currentVersionIsNewer
    case systemIsTooOld
    case systemIsTooNew
    case unsupportedHardware
    case unknown
}

enum AppUpdateFailureReason: Equatable, Sendable {
    case updaterUnavailable
    case networkUnavailable
    case invalidFeed
    case invalidMetadata
    case unknown
}

enum AppUpdateState: Equatable, Sendable {
    case idle
    case checking
    case updateUnavailable(reason: AppUpdateUnavailabilityReason)
    case updateAvailable(AvailableAppUpdate)
    case downloading(AvailableAppUpdate, progress: AppUpdateProgress)
    case extracting(AvailableAppUpdate, progress: AppUpdateProgress)
    case readyToInstall(AvailableAppUpdate)
    case installing(AvailableAppUpdate)
    case failed(reason: AppUpdateFailureReason)
}
