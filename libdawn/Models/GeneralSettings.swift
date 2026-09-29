//
//  GeneralSettings.swift
//  dawn
//
//  Created by Rafael Venetikides on 19/08/26.
//

import Foundation

public struct GeneralSettings: Codable, Equatable, Sendable {
    public var launchAtLogin: Bool = false

    public init(launchAtLogin: Bool = false) {
        self.launchAtLogin = launchAtLogin
    }
}
