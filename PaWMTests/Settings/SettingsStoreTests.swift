//
//  SettingsStoreTests.swift
//  pineapplewm
//
//  Created by Rafael Venetikides on 20/08/26.
//

import Foundation
import Testing

@testable import PaWM

@MainActor
@Suite("SettingsStore Tests")
struct SettingsStoreTests {
    @Test
    func `Missing repository document produces empty document`() async throws {
        let repository = SettingsRepositorySpy()
        let sut = try await SettingsStore(repository: repository)

        let snapshot = await sut.snapshot()

        #expect(snapshot == .empty)
    }

    @Test
    func `Existing repository document becomes the initial snapshot`() async throws {
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

        let storedDocument = SettingsDocument(
            schemaVersion: SettingsDocument.currentSchemaVersion,
            contexts: [context],
            generalSettings: GeneralSettings(launchAtLogin: true)
        )

        let repository = SettingsRepositorySpy(storedDocument: storedDocument)
        let sut = try await SettingsStore(repository: repository)

        let initialSnapshot = await sut.snapshot()

        #expect(initialSnapshot == storedDocument)
    }

    @Test
    func `Repository load errors propagate from initialization`() async {
        let expectedError = SettingsRepositoryError.corruptedData(
            description: "Invalid test data"
        )
        let repository = SettingsRepositorySpy(loadError: expectedError)

        do {
            _ = try await SettingsStore(repository: repository)
            Issue.record("Expected error creating SettingsStore")
        } catch let error as SettingsRepositoryError {
            #expect(expectedError == error)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func `Invalid loaded documents are rejected`() async throws {
        let duplicatedID = UUID()

        let firstContext = WorkspaceContext(
            id: duplicatedID,
            name: "Study",
            symbol: "book"
        )

        let secondContext = WorkspaceContext(
            id: duplicatedID,
            name: "Works",
            symbol: "briefcase"
        )

        let invalidDocument = SettingsDocument(
            schemaVersion: SettingsDocument.currentSchemaVersion,
            contexts: [firstContext, secondContext],
            generalSettings: GeneralSettings()
        )

        let repository = SettingsRepositorySpy(
            storedDocument: invalidDocument
        )

        do {
            _ = try await SettingsStore(repository: repository)
            Issue.record("Expected initialization to throw")
        } catch let error as SettingsStoreError {
            #expect(error == .duplicateContextIdentifier(duplicatedID))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func `Calling snapshot does not save anything`() async throws {
        let storedDocument = SettingsDocument.empty
        let repository = SettingsRepositorySpy(
            storedDocument: storedDocument
        )

        let sut = try await SettingsStore(repository: repository)

        let snapshot = await sut.snapshot()
        let savedDocuments = await repository.savedDocuments

        #expect(snapshot == storedDocument)
        #expect(savedDocuments.isEmpty)
    }

    @Test
    func `Whitespace context name returns emptyContextName error`() async throws {
        let application = makeApplication()
        let context = WorkspaceContext(
            name: "  \n   ",
            symbol: "book",
            applications: [application]
        )
        let document = makeDocument(
            contexts: [context]
        )

        let repository = SettingsRepositorySpy(
            storedDocument: document
        )

        do {
            _ = try await SettingsStore(repository: repository)
            Issue.record("Expected initialization to throw")
        } catch let error as SettingsStoreError {
            #expect(error == .emptyContextName)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func `Whitespace symbol returns emptyContextSymbol error`() async throws {
        let application = makeApplication()
        let context = WorkspaceContext(
            name: "Study",
            symbol: "   \n    ",
            applications: [application]
        )
        let document = makeDocument(
            contexts: [context]
        )

        let repository = SettingsRepositorySpy(
            storedDocument: document
        )

        do {
            _ = try await SettingsStore(repository: repository)
            Issue.record("Expected initialization to throw")
        } catch let error as SettingsStoreError {
            #expect(error == .emptyContextSymbol)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func `Whitespace bundle identifier returns emptyApplicationBundleIdentifier error`() async throws {
        let application = makeApplication(bundleIdentifier: "  \n   ")
        let context = WorkspaceContext(
            name: "Study",
            symbol: "book",
            applications: [application]
        )
        let document = makeDocument(
            contexts: [context]
        )

        let repository = SettingsRepositorySpy(
            storedDocument: document
        )

        do {
            _ = try await SettingsStore(repository: repository)
            Issue.record("Expected initialization to throw")
        } catch let error as SettingsStoreError {
            #expect(error == .emptyApplicationBundleIdentifier)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func `Whitespace display name returns emptyApplicationDisplayName error`() async throws {
        let application = makeApplication(displayName: "   \n   ")
        let context = WorkspaceContext(
            name: "Study",
            symbol: "book",
            applications: [application]
        )
        let document = makeDocument(
            contexts: [context]
        )

        let repository = SettingsRepositorySpy(
            storedDocument: document
        )

        do {
            _ = try await SettingsStore(repository: repository)
            Issue.record("Expected initialization to throw")
        } catch let error as SettingsStoreError {
            #expect(error == .emptyApplicationDisplayName)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func `Duplicate app UUID returns duplicateApplicationIdentifier error`() async throws {
        let duplicateID = UUID()
        let firstApplication = makeApplication(id: duplicateID)
        let secondApplication = makeApplication(id: duplicateID)
        let context = WorkspaceContext(
            name: "Study",
            symbol: "book",
            applications: [firstApplication, secondApplication]
        )
        let document = makeDocument(
            contexts: [context]
        )

        let repository = SettingsRepositorySpy(
            storedDocument: document
        )

        do {
            _ = try await SettingsStore(repository: repository)
            Issue.record("Expected initialization to throw")
        } catch let error as SettingsStoreError {
            #expect(error == .duplicateApplicationIdentifier(duplicateID))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func `Duplicate bundle id returns duplicateApplication error`() async throws {
        let bundleID = "com.apple.Safari"
        let duplicateBundleID = "   \(bundleID.uppercased())   \n"
        let firstApplication = makeApplication(bundleIdentifier: bundleID)
        let secondApplication = makeApplication(bundleIdentifier: duplicateBundleID)
        let context = WorkspaceContext(
            name: "Study",
            symbol: "book",
            applications: [firstApplication, secondApplication]
        )
        let document = makeDocument(
            contexts: [context]
        )

        let repository = SettingsRepositorySpy(
            storedDocument: document
        )

        do {
            _ = try await SettingsStore(repository: repository)
            Issue.record("Expected initialization to throw")
        } catch let error as SettingsStoreError {
            #expect(error == .duplicateApplication(bundleIdentifier: duplicateBundleID))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func `Create context persists and caches the new context`() async throws {
        let repository = SettingsRepositorySpy()
        let sut = try await SettingsStore(repository: repository)
        let applications = makeApplication()

        let created = try await sut.createContext(
            name: "Study",
            symbol: "book",
            applications: [applications]
        )

        let snapshot = await sut.snapshot()
        let savedDocuments = await repository.savedDocuments

        #expect(created.name == "Study")
        #expect(created.symbol == "book")
        #expect(created.applications == [applications])
        #expect(snapshot.contexts == [created])
        #expect(savedDocuments == [snapshot])
    }

    @Test
    func `Create context does not save or modify cache when validation fails`() async throws {
        let repository = SettingsRepositorySpy()
        let sut = try await SettingsStore(repository: repository)

        do {
            _ = try await sut.createContext(
                name: " \n ",
                symbol: "book"
            )
            Issue.record("Expected creation to throw")
        } catch let error as SettingsStoreError {
            #expect(error == .emptyContextName)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let snapshot = await sut.snapshot()
        let savedDocuments = await repository.savedDocuments

        #expect(snapshot == .empty)
        #expect(savedDocuments.isEmpty)
    }

    @Test
    func `Create context leaves cache unchanged when persistence fails`() async throws {
        let repository = SettingsRepositorySpy(
            saveError: TestError.saveFailed
        )
        let sut = try await SettingsStore(repository: repository)

        do {
            _ = try await sut.createContext(
                name: "Study",
                symbol: "book"
            )
            Issue.record("Expected creation to throw")
        } catch let error as TestError {
            #expect(error == .saveFailed)
        } catch {
            Issue.record("Unexpected Error")
        }

        let snapshot = await sut.snapshot()
        let savedDocuments = await repository.savedDocuments

        #expect(snapshot == .empty)
        #expect(savedDocuments.isEmpty)
    }

    @Test
    func `Concurrent context creations preserve every context`() async throws {
        let repository = SettingsRepositorySpy(
            yieldBeforeSaving: true
        )
        let sut = try await SettingsStore(repository: repository)
        let contextCount = 50

        try await withThrowingTaskGroup(of: WorkspaceContext.self) { group in
            for index in 0..<contextCount {
                group.addTask {
                    try await sut.createContext(
                        name: "Context \(index)",
                        symbol: "square"
                    )
                }
            }

            for try await _ in group {}
        }

        let snapshot = await sut.snapshot()
        let storedDocument = await repository.storedDocument

        #expect(snapshot.contexts.count == contextCount)
        #expect(Set(snapshot.contexts.map(\.id)).count == contextCount)
        #expect(Set(snapshot.contexts.map(\.name)).count == contextCount)
        #expect(storedDocument == snapshot)
    }

    @Test
    func `Update context persists replacement while preserving order`() async throws {
        let study = WorkspaceContext(
            name: "Study",
            symbol: "book"
        )
        let games = WorkspaceContext(
            name: "Games",
            symbol: "gamecontroller"
        )
        let initialDocument = makeDocument(
            contexts: [study, games]
        )
        let repository = SettingsRepositorySpy(
            storedDocument: initialDocument
        )
        let sut = try await SettingsStore(repository: repository)

        let application = makeApplication()
        let updatedStudy = WorkspaceContext(
            id: study.id,
            name: "University",
            symbol: "graduationcap",
            applications: [application]
        )

        try await sut.updateContext(updatedStudy)

        let snapshot = await sut.snapshot()
        let savedDocuments = await repository.savedDocuments

        #expect(snapshot.contexts == [updatedStudy, games])
        #expect(savedDocuments == [snapshot])
    }

    @Test
    func `Update context rejects an unknown identifier without saving`() async throws {
        let existing = WorkspaceContext(
            name: "Study",
            symbol: "book"
        )
        let initialDocument = makeDocument(contexts: [existing])
        let repository = SettingsRepositorySpy(
            storedDocument: initialDocument
        )
        let sut = try await SettingsStore(repository: repository)

        let unknown = WorkspaceContext(
            name: "Work",
            symbol: "briefcase"
        )

        do {
            try await sut.updateContext(unknown)
            Issue.record("Expected update to throw")
        } catch let error as SettingsStoreError {
            #expect(error == .contextNotFound(unknown.id))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let snapshot = await sut.snapshot()
        let savedDocuments = await repository.savedDocuments

        #expect(snapshot == initialDocument)
        #expect(savedDocuments.isEmpty)
    }

    @Test
    func `Update context leaves original unchanged when validation fails`() async throws {
        let existing = WorkspaceContext(
            name: "Study",
            symbol: "book"
        )
        let initialDocument = makeDocument(contexts: [existing])
        let repository = SettingsRepositorySpy(
            storedDocument: initialDocument
        )
        let sut = try await SettingsStore(repository: repository)

        let invalidReplacement = WorkspaceContext(
            id: existing.id,
            name: " \n ",
            symbol: "book"
        )

        do {
            try await sut.updateContext(invalidReplacement)
            Issue.record("Expected update to throw")
        } catch let error as SettingsStoreError {
            #expect(error == .emptyContextName)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(await sut.snapshot() == initialDocument)
        #expect(await repository.savedDocuments.isEmpty)
    }

    @Test
    func `Update context leaves original unchanged when persistence fails`() async throws {
        let existing = WorkspaceContext(
            name: "Study",
            symbol: "book"
        )
        let initialDocument = makeDocument(contexts: [existing])
        let repository = SettingsRepositorySpy(
            storedDocument: initialDocument,
            saveError: TestError.saveFailed
        )
        let sut = try await SettingsStore(repository: repository)

        let replacement = WorkspaceContext(
            id: existing.id,
            name: "University",
            symbol: "graduationcap"
        )

        do {
            try await sut.updateContext(replacement)
            Issue.record("Expected update to throw")
        } catch let error as TestError {
            #expect(error == .saveFailed)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(await sut.snapshot() == initialDocument)
        #expect(await repository.savedDocuments.isEmpty)
    }

    @Test
    func `Delete context persists removal while preserving remaining order`() async throws {
        let study = WorkspaceContext(
            name: "Study",
            symbol: "book"
        )
        let games = WorkspaceContext(
            name: "Games",
            symbol: "gamecontroller"
        )
        let work = WorkspaceContext(
            name: "Work",
            symbol: "briefcase"
        )

        let initialDocument = makeDocument(
            contexts: [study, games, work]
        )
        let repository = SettingsRepositorySpy(
            storedDocument: initialDocument
        )
        let sut = try await SettingsStore(repository: repository)

        try await sut.deleteContext(id: games.id)

        let snapshot = await sut.snapshot()
        let savedDocuments = await repository.savedDocuments

        #expect(snapshot.contexts == [study, work])
        #expect(savedDocuments == [snapshot])
    }

    @Test
    func `Delete context rejects an unknown identifier without saving`() async throws {
        let existing = WorkspaceContext(
            name: "Study",
            symbol: "book"
        )
        let initialDocument = makeDocument(contexts: [existing])
        let repository = SettingsRepositorySpy(
            storedDocument: initialDocument
        )
        let sut = try await SettingsStore(repository: repository)
        let unknownID = UUID()

        do {
            try await sut.deleteContext(id: unknownID)
            Issue.record("Expected deletion to throw")
        } catch let error as SettingsStoreError {
            #expect(error == .contextNotFound(unknownID))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(await sut.snapshot() == initialDocument)
        #expect(await repository.savedDocuments.isEmpty)
    }

    @Test
    func `Delete context leaves original unchanged when persistence fails`() async throws {
        let existing = WorkspaceContext(
            name: "Study",
            symbol: "book"
        )
        let initialDocument = makeDocument(contexts: [existing])
        let repository = SettingsRepositorySpy(
            storedDocument: initialDocument,
            saveError: TestError.saveFailed
        )
        let sut = try await SettingsStore(repository: repository)

        do {
            try await sut.deleteContext(id: existing.id)
            Issue.record("Expected deletion to throw")
        } catch let error as TestError {
            #expect(error == .saveFailed)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(await sut.snapshot() == initialDocument)
        #expect(await repository.savedDocuments.isEmpty)
    }

    @Test
    func `Set launch at login persists preference without changing contexts`() async throws {
        let context = WorkspaceContext(
            name: "Study",
            symbol: "book"
        )
        let initialDocument = makeDocument(contexts: [context])
        let repository = SettingsRepositorySpy(
            storedDocument: initialDocument
        )
        let sut = try await SettingsStore(repository: repository)

        try await sut.setLaunchAtLogin(true)

        let snapshot = await sut.snapshot()
        let savedDocuments = await repository.savedDocuments

        #expect(snapshot.generalSettings.launchAtLogin)
        #expect(snapshot.contexts == [context])
        #expect(savedDocuments == [snapshot])
    }

    @Test
    func `Set launch at login supports enabling and disabling`() async throws {
        let repository = SettingsRepositorySpy()
        let sut = try await SettingsStore(repository: repository)

        try await sut.setLaunchAtLogin(true)
        try await sut.setLaunchAtLogin(false)

        let snapshot = await sut.snapshot()
        let savedDocuments = await repository.savedDocuments

        #expect(snapshot.generalSettings.launchAtLogin == false)
        #expect(savedDocuments.count == 2)
        #expect(
            savedDocuments[0].generalSettings.launchAtLogin == true
        )
        #expect(
            savedDocuments[1].generalSettings.launchAtLogin == false
        )
    }

    @Test
    func `Set launch at login leaves preference unchanged when persistence fails`() async throws {
        let initialDocument = SettingsDocument.empty
        let repository = SettingsRepositorySpy(
            storedDocument: initialDocument,
            saveError: TestError.saveFailed
        )
        let sut = try await SettingsStore(repository: repository)

        do {
            try await sut.setLaunchAtLogin(true)
            Issue.record("Expected update to throw")
        } catch let error as TestError {
            #expect(error == .saveFailed)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(await sut.snapshot() == initialDocument)
        #expect(await repository.savedDocuments.isEmpty)
    }

    private func makeDocument(
        contexts: [WorkspaceContext]
    ) -> SettingsDocument {
        SettingsDocument(
            schemaVersion: SettingsDocument.currentSchemaVersion,
            contexts: contexts,
            generalSettings: GeneralSettings()
        )
    }

    private func makeApplication(
        id: UUID = UUID(),
        bundleIdentifier: String = "com.apple.Safari",
        displayName: String = "Safari"
    ) -> WorkspaceApplication {
        WorkspaceApplication(
            id: id,
            bundleIdentifier: bundleIdentifier,
            displayName: displayName
        )
    }
}

private actor SettingsRepositorySpy: SettingsRepository {
    var storedDocument: SettingsDocument?
    var loadError: (any Error)?
    var saveError: (any Error)?
    var yieldBeforeSaving: Bool
    private(set) var savedDocuments: [SettingsDocument] = []

    init(
        storedDocument: SettingsDocument? = nil,
        loadError: (any Error)? = nil,
        saveError: (any Error)? = nil,
        yieldBeforeSaving: Bool = false
    ) {
        self.storedDocument = storedDocument
        self.loadError = loadError
        self.saveError = saveError
        self.yieldBeforeSaving = yieldBeforeSaving
    }

    func load() async throws -> SettingsDocument? {
        if let loadError {
            throw loadError
        }

        return storedDocument
    }

    func save(_ document: SettingsDocument) async throws {
        if let saveError {
            throw saveError
        }

        if yieldBeforeSaving {
            await Task.yield()
        }

        savedDocuments.append(document)
        storedDocument = document
    }
}

private enum TestError: Error, Equatable {
    case saveFailed
}
