//
//  Settings.swift
//  dawn
//
//  Created by Rafael Venetikides on 19/08/26.
//

import Foundation

public struct Settings: Codable, Equatable, Sendable {
    public var launchAtLogin: Bool
    public var showInMenuBar: Bool
    public var forceAppsToQuit: Bool
    public var analyticsEnabled: Bool
    public var protectedApps: [ProtectedApplication]

    public init(
        launchAtLogin: Bool = false,
        showInMenuBar: Bool = true,
        forceAppsToQuit: Bool = false,
        analyticsEnabled: Bool = false,
        protectedApps: [ProtectedApplication] = []
    ) {
        self.launchAtLogin = launchAtLogin
        self.showInMenuBar = showInMenuBar
        self.forceAppsToQuit = forceAppsToQuit
        self.analyticsEnabled = analyticsEnabled
        self.protectedApps = protectedApps
    }

    private enum CodingKeys: String, CodingKey {
        case launchAtLogin
        case showInMenuBar
        case forceAppsToQuit
        case analyticsEnabled
        case protectedApps
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        launchAtLogin =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .launchAtLogin
            ) ?? false

        showInMenuBar =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .showInMenuBar
            ) ?? true

        forceAppsToQuit =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .forceAppsToQuit
            ) ?? false

        analyticsEnabled =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .analyticsEnabled
            ) ?? false

        protectedApps =
            try container.decodeIfPresent(
                [ProtectedApplication].self,
                forKey: .protectedApps
            ) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(
            keyedBy: CodingKeys.self
        )

        try container.encode(
            launchAtLogin,
            forKey: .launchAtLogin
        )

        try container.encode(
            showInMenuBar,
            forKey: .showInMenuBar
        )

        try container.encode(
            forceAppsToQuit,
            forKey: .forceAppsToQuit
        )

        try container.encode(
            analyticsEnabled,
            forKey: .analyticsEnabled
        )

        try container.encode(
            protectedApps,
            forKey: .protectedApps
        )
    }
}
