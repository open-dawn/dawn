//
//  UserDefaultsSettingsRepositoryTests.swift
//  dawn
//
//  Created by Rafael Venetikides on 20/08/26.
//

import Foundation
import libdawn
import Testing

@testable import dawnAgent

@MainActor
@Suite("UserDefaultsSettingsRepository Tests")
struct UserDefaultsSettingsRepositoryTests {
    @Test("Load returns nil when no document exists")
    func loadReturnsNilWhenMissing() async throws {
        let sut = RepositoryFixture()
        defer { sut.cleanUp() }

        let document = try await sut.repository.load()

        #expect(document == nil)
    }

    @Test("Save and load preserves the complete document")
    func saveAndLoadRoundTripsDocument() async throws {
        let sut = RepositoryFixture()
        defer { sut.cleanUp() }

        let application = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            applicationURL: URL(
                fileURLWithPath: "/Applications/Safari.app"
            )
        )

        let workspace = Workspace(
            name: "Study",
            symbol: "book",
            applications: [application]
        )

        let expected = SettingsDocument(
            schemaVersion: SettingsDocument.currentSchemaVersion,
            workspaces: [workspace],
            generalSettings: Settings(launchAtLogin: true)
        )

        try await sut.repository.save(expected)
        let loaded = try await sut.repository.load()

        #expect(loaded == expected)
    }

    @Test("Load rejects a stored value that is not data")
    func loadRejectsNonDataValue() async {
        let sut = RepositoryFixture()
        defer { sut.cleanUp() }

        sut.defaults.set(
            "invalid settings",
            forKey: UserDefaultsSettingsRepository.defaultsStorageKey
        )

        do {
            _ = try await sut.repository.load()
            Issue.record("Expected loading to throw")
        } catch let error as SettingsRepositoryError {
            guard case .corruptedData = error else {
                Issue.record("Unexpected repository error: \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(
            sut.defaults.string(
                forKey: UserDefaultsSettingsRepository.defaultsStorageKey
            ) == "invalid settings"
        )
    }

    @Test("Load rejects malformed document data without deleting it")
    func loadRejectsMalformedData() async {
        let sut = RepositoryFixture()
        defer { sut.cleanUp() }

        let malformedData = Data("not valid JSON".utf8)

        sut.defaults.set(
            malformedData,
            forKey: UserDefaultsSettingsRepository.defaultsStorageKey
        )

        do {
            _ = try await sut.repository.load()
            Issue.record("Expected loading to throw")
        } catch let error as SettingsRepositoryError {
            guard case .corruptedData = error else {
                Issue.record("Unexpected repository error: \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(
            sut.defaults.data(
                forKey: UserDefaultsSettingsRepository.defaultsStorageKey
            ) == malformedData
        )
    }

    @Test("Load rejects an unsupported schema version")
    func loadRejectsUnsupportedSchema() async throws {
        let sut = RepositoryFixture()
        defer { sut.cleanUp() }

        let unsupportedDocument = SettingsDocument(
            schemaVersion: 999,
            workspaces: [],
            generalSettings: Settings()
        )

        let originalData = try JSONEncoder().encode(unsupportedDocument)

        sut.defaults.set(
            originalData,
            forKey: UserDefaultsSettingsRepository.defaultsStorageKey
        )

        do {
            _ = try await sut.repository.load()
            Issue.record("Expected loading to throw")
        } catch let error as SettingsRepositoryError {
            #expect(error == .unsupportedSchemaVersion(999))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(
            sut.defaults.data(
                forKey: UserDefaultsSettingsRepository.defaultsStorageKey
            ) == originalData
        )
    }

    @Test("Load migrates a v2 document to v3 preserving workspace data")
    func loadMigratesV2Document() async throws {
        let sut = RepositoryFixture()
        defer { sut.cleanUp() }

        let expected = Self.makeDocumentWithActivity()
        let v2Data = try Self.makeLegacyV2Data(from: expected)

        sut.defaults.set(
            v2Data,
            forKey: UserDefaultsSettingsRepository.defaultsStorageKey
        )

        let loaded = try await sut.repository.load()

        #expect(loaded == expected)
        #expect(loaded?.schemaVersion == 3)
        #expect(loaded?.workspaces.count == 2)
        #expect(loaded?.workspaceActivity.activeWorkspaceID == expected.workspaceActivity.activeWorkspaceID)
    }

    @Test("A migrated v2 document round-trips through save and load")
    func migratedDocumentRoundTrips() async throws {
        let sut = RepositoryFixture()
        defer { sut.cleanUp() }

        let expected = Self.makeDocumentWithActivity()

        sut.defaults.set(
            try Self.makeLegacyV2Data(from: expected),
            forKey: UserDefaultsSettingsRepository.defaultsStorageKey
        )

        let migrated = try #require(try await sut.repository.load())
        try await sut.repository.save(migrated)
        let reloaded = try await sut.repository.load()

        #expect(reloaded == expected)

        let storedData = try #require(
            sut.defaults.data(forKey: UserDefaultsSettingsRepository.defaultsStorageKey)
        )
        let stored = try #require(
            try JSONSerialization.jsonObject(with: storedData) as? [String: Any]
        )

        #expect(stored["schemaVersion"] as? Int == 3)
        #expect(stored["workspaces"] != nil)
        #expect(stored["contexts"] == nil)
    }

    @Test("Migration renames context keys to workspace keys")
    func migrationRenamesKeys() throws {
        let expected = Self.makeDocumentWithActivity()
        let v2Data = try Self.makeLegacyV2Data(from: expected)

        let migrated = try SettingsDocumentMigration.migrateV2ToV3(v2Data)
        let root = try #require(
            try JSONSerialization.jsonObject(with: migrated) as? [String: Any]
        )
        let activity = try #require(root["workspaceActivity"] as? [String: Any])
        let session = try #require(activity["activeSession"] as? [String: Any])

        #expect(root["schemaVersion"] as? Int == 3)
        #expect(root["workspaces"] != nil)
        #expect(root["contexts"] == nil)
        #expect(activity["lastActiveAtByWorkspaceID"] != nil)
        #expect(activity["lastActiveAtByContextID"] == nil)
        #expect(session["workspaceID"] != nil)
        #expect(session["contextID"] == nil)
    }

    @Test("Load migrates an empty v2 document")
    func loadMigratesEmptyV2Document() async throws {
        let sut = RepositoryFixture()
        defer { sut.cleanUp() }

        let v2Data = try Self.makeLegacyV2Data(from: .empty)

        sut.defaults.set(
            v2Data,
            forKey: UserDefaultsSettingsRepository.defaultsStorageKey
        )

        let loaded = try await sut.repository.load()

        #expect(loaded == .empty)
    }

    @Test("Save rejects unsupported schema without replacing existing data")
    func saveRejectsUnsupportedSchema() async throws {
        let sut = RepositoryFixture()
        defer { sut.cleanUp() }

        try await sut.repository.save(.empty)

        let originalData = sut.defaults.data(
            forKey: UserDefaultsSettingsRepository.defaultsStorageKey
        )

        let unsupportedDocument = SettingsDocument(
            schemaVersion: 999,
            workspaces: [],
            generalSettings: Settings()
        )

        do {
            try await sut.repository.save(unsupportedDocument)
            Issue.record("Expected saving to throw")
        } catch let error as SettingsRepositoryError {
            #expect(error == .unsupportedSchemaVersion(999))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(
            sut.defaults.data(
                forKey: UserDefaultsSettingsRepository.defaultsStorageKey
            ) == originalData
        )
    }

    private static func makeDocumentWithActivity() -> SettingsDocument {
        let first = Workspace(
            name: "Study",
            symbol: "book",
            applications: [
                WorkspaceApplication(
                    bundleIdentifier: "com.apple.Safari",
                    displayName: "Safari",
                    applicationURL: URL(fileURLWithPath: "/Applications/Safari.app")
                )
            ]
        )
        let second = Workspace(name: "Play", symbol: "gamecontroller")

        var activity = WorkspaceActivityState.empty
        activity.activate(workspaceID: first.id, at: Date(timeIntervalSince1970: 1_000))
        activity.activate(workspaceID: second.id, at: Date(timeIntervalSince1970: 2_000))

        return SettingsDocument(
            schemaVersion: SettingsDocument.currentSchemaVersion,
            workspaces: [first, second],
            generalSettings: Settings(launchAtLogin: true),
            workspaceActivity: activity
        )
    }

    /// Encodes `document` with the current schema, then rewrites it into the v2 "context" shape.
    private static func makeLegacyV2Data(from document: SettingsDocument) throws -> Data {
        let encoded = try JSONEncoder().encode(document)
        var root = try #require(
            try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )

        root["contexts"] = root.removeValue(forKey: "workspaces")
        root["schemaVersion"] = 2

        if var activity = root["workspaceActivity"] as? [String: Any] {
            activity["lastActiveAtByContextID"] = activity.removeValue(
                forKey: "lastActiveAtByWorkspaceID"
            )

            if var session = activity["activeSession"] as? [String: Any] {
                session["contextID"] = session.removeValue(forKey: "workspaceID")
                activity["activeSession"] = session
            }

            root["workspaceActivity"] = activity
        }

        return try JSONSerialization.data(withJSONObject: root)
    }
}

@MainActor
private struct RepositoryFixture {
    let suiteName: String
    let defaults: UserDefaults
    let repository: UserDefaultsSettingsRepository

    init() {
        let suiteName = "UserDefaultsSettingsRepositoryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        defaults.removePersistentDomain(forName: suiteName)

        self.suiteName = suiteName
        self.defaults = defaults
        self.repository = UserDefaultsSettingsRepository(
            defaults: defaults
        )
    }

    func cleanUp() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}
