//
//  SettingsDocument.swift
//  dawn
//
//  Created by Rafael Venetikides on 19/08/26.
//

import Foundation
import libdawn

struct SettingsDocument: Codable, Equatable, Sendable {

    static let currentSchemaVersion = 1

    let schemaVersion: Int
    var contexts: [WorkspaceContext]
    var generalSettings: Settings

    static var empty: SettingsDocument {
        SettingsDocument(
            schemaVersion: currentSchemaVersion,
            contexts: [],
            generalSettings: Settings()
        )
    }
}
