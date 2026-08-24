//
//  SettingsDocument.swift
//  pineapplewm
//
//  Created by Rafael Venetikides on 19/08/26.
//

import Foundation

struct SettingsDocument: Codable, Equatable, Sendable {

    static let currentSchemaVersion = 1

    let schemaVersion: Int
    var contexts: [WorkspaceContext]
    var generalSettings: GeneralSettings

    static var empty: SettingsDocument {
        SettingsDocument(
            schemaVersion: currentSchemaVersion,
            contexts: [],
            generalSettings: GeneralSettings()
        )
    }
}
