//
//  SettingsDocumentMigration.swift
//  dawn
//

import Foundation

/// Upgrades persisted settings JSON from older schema versions.
enum SettingsDocumentMigration {

    /// Schema version that still used the "context" vocabulary.
    static let legacyContextSchemaVersion = 2

    enum MigrationError: Error, Equatable {
        case notAJSONObject
    }

    /// Migrates a schema v2 document ("context" keys) to schema v3 ("workspace" keys).
    ///
    /// - `contexts` → `workspaces`
    /// - `workspaceActivity.lastActiveAtByContextID` → `lastActiveAtByWorkspaceID`
    /// - `workspaceActivity.activeSession.contextID` → `workspaceID`
    /// - `schemaVersion` → 3
    static func migrateV2ToV3(_ data: Data) throws -> Data {
        guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MigrationError.notAJSONObject
        }

        rename("contexts", to: "workspaces", in: &root)

        if var activity = root["workspaceActivity"] as? [String: Any] {
            rename("lastActiveAtByContextID", to: "lastActiveAtByWorkspaceID", in: &activity)

            if var session = activity["activeSession"] as? [String: Any] {
                rename("contextID", to: "workspaceID", in: &session)
                activity["activeSession"] = session
            }

            root["workspaceActivity"] = activity
        }

        root["schemaVersion"] = SettingsDocument.currentSchemaVersion

        return try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
    }

    private static func rename(
        _ oldKey: String,
        to newKey: String,
        in object: inout [String: Any]
    ) {
        guard let value = object.removeValue(forKey: oldKey) else {
            return
        }

        if object[newKey] == nil {
            object[newKey] = value
        }
    }
}
