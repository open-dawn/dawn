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

    public init(launchAtLogin: Bool = false, showInMenuBar: Bool = true) {
        self.launchAtLogin = launchAtLogin
        self.showInMenuBar = showInMenuBar
    }

    private enum CodingKeys: String, CodingKey {
        case launchAtLogin
        case showInMenuBar
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
    }
}
