//
//  UserDefaultsSettingsRepositoryTests.swift
//  pineapplewm
//
//  Created by Rafael Venetikides on 20/08/26.
//

import Foundation
import PaEventKit
import Testing

@testable import PaWM

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

        let context = WorkspaceContext(
            name: "Study",
            symbol: "book",
            applications: [application]
        )

        let expected = SettingsDocument(
            schemaVersion: SettingsDocument.currentSchemaVersion,
            contexts: [context],
            generalSettings: GeneralSettings(launchAtLogin: true)
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
            contexts: [],
            generalSettings: GeneralSettings()
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
            contexts: [],
            generalSettings: GeneralSettings()
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
