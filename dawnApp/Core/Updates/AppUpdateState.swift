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

enum AppUpdateState: Equatable, Sendable {
    case idle
    case checking
    case upToDate
    case updateAvailable(AvailableAppUpdate)
    case downloading(AvailableAppUpdate, progress: AppUpdateProgress)
    case extracting(AvailableAppUpdate, progress: AppUpdateProgress)
    case readyToInstall(AvailableAppUpdate)
    case installing(AvailableAppUpdate)
    case failed(message: String)
}
