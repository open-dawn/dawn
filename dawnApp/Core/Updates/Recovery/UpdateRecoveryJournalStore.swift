//
//  UpdateRecoveryJournalStore.swift
//  dawn
//
//  Created by Rafael Venetikides on 12/11/26.
//

import Foundation

protocol UpdateRecoveryJournalStoring {
    func load() throws -> UpdateRecoveryJournal?
    func save(_ journal: UpdateRecoveryJournal) throws
    func clear() throws
}

enum UpdateRecoveryJournalStoreError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
}

struct FileUpdateRecoveryJournalStore: UpdateRecoveryJournalStoring {
    static let defaultFileURL = URL.applicationSupportDirectory.appending(
            path: "app.opendawn.dawnApp",
            directoryHint: .isDirectory
        )
        .appending(
            path: "update-recovery.json",
            directoryHint: .notDirectory
        )

    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL = Self.defaultFileURL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder

        decoder = JSONDecoder()
    }

    func load() throws -> UpdateRecoveryJournal? {
        guard fileManager.fileExists(atPath: fileURL.path()) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        let journal = try decoder.decode(UpdateRecoveryJournal.self, from: data)

        guard journal.schemaVersion == UpdateRecoveryJournal.currentSchemaVersion else {
            throw UpdateRecoveryJournalStoreError.unsupportedSchemaVersion(journal.schemaVersion)
        }

        return journal
    }

    func save(_ journal: UpdateRecoveryJournal) throws {
        let directoryURL = fileURL.deletingLastPathComponent()

        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let data = try encoder.encode(journal)
        try data.write(to: fileURL, options: .atomic)
    }

    func clear() throws {
        guard fileManager.fileExists(atPath: fileURL.path()) else {
            return
        }

        try fileManager.removeItem(at: fileURL)
    }
}
