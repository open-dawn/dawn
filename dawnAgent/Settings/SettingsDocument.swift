//
//  SettingsDocument.swift
//  dawn
//
//  Created by Rafael Venetikides on 19/08/26.
//

import Foundation
import libdawn

struct SettingsDocument: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 3

    let schemaVersion: Int
    var workspaces: [Workspace]
    var generalSettings: Settings
    var workspaceActivity: WorkspaceActivityState = .empty

    static var empty: SettingsDocument {
        SettingsDocument(
            schemaVersion: currentSchemaVersion,
            workspaces: [],
            generalSettings: Settings(),
            workspaceActivity: .empty
        )
    }
}
