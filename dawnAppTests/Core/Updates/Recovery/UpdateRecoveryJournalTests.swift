//
//  UpdateRecoveryJournalTests.swift
//  dawn
//
//  Created by Rafael Venetikides on 12/11/26.
//

import Foundation
import Testing

@testable import dawnApp

@Suite("UpdateRecoveryJournalTests")
struct UpdateRecoveryJournalTests {
    private var journal: UpdateRecoveryJournal {
        UpdateRecoveryJournal(
            sourceBuild: "41",
            targetBuild: "42",
            components: [
                UpdateComponentRecoveryRecord(
                    identifier: "app.opendawn.dawnAgent",
                    previousRegistrationState: .enabled,
                    preparationPhase: .prepared
                )
            ]
        )
    }

    @Test("Missing file returns nil")
    func missingFileReturnsNil() throws {
        let fixture = makeStore()
        defer { remove(fixture.directoryURL) }

        let loaded = try fixture.store.load()

        #expect(loaded == nil)
    }

    @Test("Journal survives a save and load round trip")
    func saveAndLoadRoundTrip() throws {
        let fixture = makeStore()
        defer { remove(fixture.directoryURL) }

        try fixture.store.save(journal)
        let loaded = try fixture.store.load()

        #expect(loaded == journal)
        #expect(
            FileManager.default.fileExists(
                atPath: fixture.fileURL.path()
            )
        )
    }

    @Test("Saving creates the parent directory")
    func saveCreatesParentDirectory() throws {
        let fixture = makeStore()
        defer { remove(fixture.directoryURL) }

        #expect(
            !FileManager.default.fileExists(
                atPath: fixture.directoryURL.path()
            )
        )

        try fixture.store.save(journal)

        #expect(
            FileManager.default.fileExists(
                atPath: fixture.directoryURL.path()
            )
        )
    }

    @Test("A later save replaces the previous journal")
    func saveReplacesPreviousJournal() throws {
        let fixture = makeStore()
        defer { remove(fixture.directoryURL) }

        let replacement = UpdateRecoveryJournal(
            sourceBuild: "42",
            targetBuild: "43",
            components: [
                UpdateComponentRecoveryRecord(
                    identifier: "app.opendawn.dawnAgent",
                    previousRegistrationState: .requiresApproval,
                    preparationPhase: .preparing
                )
            ]
        )

        try fixture.store.save(journal)
        try fixture.store.save(replacement)

        let loaded = try fixture.store.load()

        #expect(loaded == replacement)
    }

    @Test("Clear removes the saved journal")
    func clearRemovesJournal() throws {
        let fixture = makeStore()
        defer { remove(fixture.directoryURL) }

        try fixture.store.save(journal)
        try fixture.store.clear()

        let loaded = try fixture.store.load()

        #expect(loaded == nil)
        #expect(
            !FileManager.default.fileExists(
                atPath: fixture.fileURL.path()
            )
        )
    }

    @Test("Clearing without a journal succeeds")
    func clearingMissingJournalSucceeds() throws {
        let fixture = makeStore()
        defer { remove(fixture.directoryURL) }

        try fixture.store.clear()

        let loaded = try fixture.store.load()
        #expect(loaded == nil)
    }

    @Test("Malformed journal data is reported")
    func malformedDataThrows() throws {
        let fixture = makeStore()
        defer { remove(fixture.directoryURL) }

        try fixture.store.save(journal)

        try Data("not valid JSON".utf8).write(
            to: fixture.fileURL,
            options: .atomic
        )

        #expect(throws: DecodingError.self) {
            _ = try fixture.store.load()
        }
    }

    @Test("Unsupported schema version is reported")
    func unsupportedSchemaVersionThrows() throws {
        let fixture = makeStore()
        defer { remove(fixture.directoryURL) }

        let unsupportedVersion =
            UpdateRecoveryJournal.currentSchemaVersion + 1

        let unsupportedJournal = UpdateRecoveryJournal(
            schemaVersion: unsupportedVersion,
            sourceBuild: "41",
            targetBuild: "42",
            components: []
        )

        try fixture.store.save(unsupportedJournal)

        #expect(
            throws:
                UpdateRecoveryJournalStoreError
                .unsupportedSchemaVersion(unsupportedVersion)
        ) {
            _ = try fixture.store.load()
        }
    }

    private struct JournalStoreFixture {
        let store: FileUpdateRecoveryJournalStore
        let directoryURL: URL
        let fileURL: URL
    }

    private func makeStore() -> JournalStoreFixture {
        let directoryURL = FileManager.default.temporaryDirectory
            .appending(
                path: "dawn-update-journal-\(UUID().uuidString)",
                directoryHint: .isDirectory
            )

        let fileURL = directoryURL.appending(
            path: "journal.json",
            directoryHint: .notDirectory
        )

        return JournalStoreFixture(
            store: FileUpdateRecoveryJournalStore(fileURL: fileURL),
            directoryURL: directoryURL,
            fileURL: fileURL
        )
    }

    private func remove(_ directoryURL: URL) {
        try? FileManager.default.removeItem(at: directoryURL)
    }
}
