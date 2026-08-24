//
//  SettingsStorageIntegrationTests.swift
//  pineapplewm
//
//  Created by Rafael Venetikides on 21/08/26.
//

import Foundation
import Testing

@testable import PaWM

@MainActor
@Suite("Settings Storage Integration Tests")
struct SettingsStorageIntegrationTests {
    @Test("Settings survive recreating repository and store")
    func settingsSurviveStoreRecreation() async throws {
        let suiteName = "SettingsStorageIntegrationTests.\(UUID().uuidString)"
        let defaults = try #require(
            UserDefaults(suiteName: suiteName)
        )

        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let taskReturn = Task { @MainActor in
            return UserDefaultsSettingsRepository(
                defaults: defaults
            )
        }

        let firstRepository: UserDefaultsSettingsRepository

        switch await taskReturn.result {
        case .success(let returntedRepository):
            firstRepository = returntedRepository
        case .failure:
            Issue.record("Error creating first UserDefaultsRepository")
            return
        }

        let firstStore = try await SettingsStore(
            repository: firstRepository
        )

        let study = try await firstStore.createContext(
            name: "Study",
            symbol: "book"
        )

        let games = try await firstStore.createContext(
            name: "Games",
            symbol: "gamecontroller"
        )

        let safari = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            applicationURL: URL(
                fileURLWithPath: "/applications/Safari.app"
            )
        )

        let updatedStudy = WorkspaceContext(
            id: study.id,
            name: "Deep work",
            symbol: "brain",
            applications: [safari]
        )

        try await firstStore.updateContext(updatedStudy)
        try await firstStore.deleteContext(id: games.id)
        try await firstStore.setLaunchAtLogin(true)

        let expectedDocument = await firstStore.snapshot()

        let reloadedDefaults = try #require(
            UserDefaults(suiteName: suiteName)
        )

        let secondTaskReturn = Task { @MainActor in
            return UserDefaultsSettingsRepository(
                defaults: reloadedDefaults
            )
        }

        let secondRepository: UserDefaultsSettingsRepository

        switch await secondTaskReturn.result {
        case .failure:
            Issue.record("Error creating second UserDefaultsRepository")
            return
        case .success(let returnedRepository):
            secondRepository = returnedRepository
        }

        let secondStore = try await SettingsStore(
            repository: secondRepository
        )

        let reloadedDocument = await secondStore.snapshot()

        #expect(reloadedDocument == expectedDocument)
        #expect(reloadedDocument.contexts == [updatedStudy])
        #expect(reloadedDocument.generalSettings.launchAtLogin)
        #expect(
            reloadedDocument.schemaVersion == SettingsDocument.currentSchemaVersion
        )
    }
}
