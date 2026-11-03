//
//  AppUpdating.swift
//  dawn
//
//  Created by Rafael Venetikides on 30/10/26.
//

import Observation

@MainActor
protocol AppUpdating: AnyObject, Observable {
    var state: AppUpdateState { get }
    var canCheckForUpdates: Bool { get }

    func checkForUpdates()
    func installAvailableUpdate()
    func installAndRelaunch()
    func cancelUpdate()
}
