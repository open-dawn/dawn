//
//  UserDefaultsSettingsRepository.swift
//  dawn
//
//  Created by Rafael Venetikides on 19/08/26.
//

import Foundation

actor UserDefaultsSettingsRepository: SettingsRepository {

    static let defaultsStorageKey = "settings.document"

    private let defaults: UserDefaults
    private let storageKey: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = defaultsStorageKey
    ) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        self.defaults = defaults
        self.storageKey = storageKey
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    func load() async throws -> SettingsDocument? {
        guard let storedValue = defaults.object(forKey: storageKey) else {
            return nil
        }

        guard let data = storedValue as? Data else {
            throw SettingsRepositoryError.corruptedData(
                description: "Stored settings value is not Data"
            )
        }

        let header: SettingsDocumentHeader

        do {
            header = try decoder.decode(
                SettingsDocumentHeader.self,
                from: data
            )
        } catch {
            throw SettingsRepositoryError.corruptedData(
                description: String(describing: error)
            )
        }

        guard header.schemaVersion == SettingsDocument.currentSchemaVersion else {
            throw SettingsRepositoryError.unsupportedSchemaVersion(
                header.schemaVersion
            )
        }

        do {
            return try decoder.decode(SettingsDocument.self, from: data)
        } catch {
            throw SettingsRepositoryError.corruptedData(
                description: String(describing: error)
            )
        }
    }

    func save(_ document: SettingsDocument) async throws {
        guard document.schemaVersion == SettingsDocument.currentSchemaVersion else {
            throw SettingsRepositoryError.unsupportedSchemaVersion(
                document.schemaVersion
            )
        }

        let data: Data

        do {
            data = try encoder.encode(document)
        } catch {
            throw SettingsRepositoryError.encodingFailed(
                description: String(describing: error)
            )
        }

        defaults.set(data, forKey: storageKey)
    }
}

private struct SettingsDocumentHeader: Decodable {
    let schemaVersion: Int
}
