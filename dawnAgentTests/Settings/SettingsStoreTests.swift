//
//  SettingsStoreTests.swift
//  dawn
//
//  Created by Rafael Venetikides on 20/08/26.
//

import Foundation
import Testing
import libdawn

@testable import dawnAgent

@MainActor
@Suite("SettingsStore Tests")
struct SettingsStoreTests {
    @Test("Missing repository document produces empty document")
    func missingDocumentUsesEmptySettings() async throws {
        let repository = SettingsRepositorySpy()
        let sut = try await SettingsStore(repository: repository)

        let snapshot = await sut.snapshot()

        #expect(snapshot == .empty)
    }

    @Test("Existing repository document becomes the initial snapshot")
    func existingDocumentBecomesSnapshot() async throws {
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

        let storedDocument = SettingsDocument(
            schemaVersion: SettingsDocument.currentSchemaVersion,
            workspaces: [workspace],
            generalSettings: Settings(launchAtLogin: true)
        )

        let repository = SettingsRepositorySpy(storedDocument: storedDocument)
        let sut = try await SettingsStore(repository: repository)

        let initialSnapshot = await sut.snapshot()

        #expect(initialSnapshot == storedDocument)
    }

    @Test("Repository load errors propagate from initialization")
    func loadErrorsPropagate() async {
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

    @Test("Invalid loaded documents are rejected")
    func invalidDocumentsAreRejected() async throws {
        let duplicatedID = UUID()

        let firstWorkspace = Workspace(
            id: duplicatedID,
            name: "Study",
            symbol: "book"
        )

        let secondWorkspace = Workspace(
            id: duplicatedID,
            name: "Works",
            symbol: "briefcase"
        )

        let invalidDocument = SettingsDocument(
            schemaVersion: SettingsDocument.currentSchemaVersion,
            workspaces: [firstWorkspace, secondWorkspace],
            generalSettings: Settings()
        )

        let repository = SettingsRepositorySpy(
            storedDocument: invalidDocument
        )

        do {
            _ = try await SettingsStore(repository: repository)
            Issue.record("Expected initialization to throw")
        } catch let error as SettingsStoreError {
            #expect(error == .duplicateWorkspaceIdentifier(duplicatedID))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Calling snapshot does not save anything")
    func snapshotDoesNotSave() async throws {
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

    @Test("Whitespace workspace name returns emptyWorkspaceName error")
    func emptyWorkspaceNameIsRejected() async throws {
        let application = makeApplication()
        let workspace = Workspace(
            name: "  \n   ",
            symbol: "book",
            applications: [application]
        )
        let document = makeDocument(
            workspaces: [workspace]
        )

        let repository = SettingsRepositorySpy(
            storedDocument: document
        )

        do {
            _ = try await SettingsStore(repository: repository)
            Issue.record("Expected initialization to throw")
        } catch let error as SettingsStoreError {
            #expect(error == .emptyWorkspaceName)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Whitespace symbol returns emptyWorkspaceSymbol error")
    func emptyWorkspaceSymbolIsRejected() async throws {
        let application = makeApplication()
        let workspace = Workspace(
            name: "Study",
            symbol: "   \n    ",
            applications: [application]
        )
        let document = makeDocument(
            workspaces: [workspace]
        )

        let repository = SettingsRepositorySpy(
            storedDocument: document
        )

        do {
            _ = try await SettingsStore(repository: repository)
            Issue.record("Expected initialization to throw")
        } catch let error as SettingsStoreError {
            #expect(error == .emptyWorkspaceSymbol)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Whitespace bundle identifier returns emptyApplicationBundleIdentifier error")
    func emptyBundleIdentifierIsRejected() async throws {
        let application = makeApplication(bundleIdentifier: "  \n   ")
        let workspace = Workspace(
            name: "Study",
            symbol: "book",
            applications: [application]
        )
        let document = makeDocument(
            workspaces: [workspace]
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

    @Test("Whitespace display name returns emptyApplicationDisplayName error")
    func emptyDisplayNameIsRejected() async throws {
        let application = makeApplication(displayName: "   \n   ")
        let workspace = Workspace(
            name: "Study",
            symbol: "book",
            applications: [application]
        )
        let document = makeDocument(
            workspaces: [workspace]
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

    @Test("Duplicate app UUID returns duplicateApplicationIdentifier error")
    func duplicateApplicationIDIsRejected() async throws {
        let duplicateID = UUID()
        let firstApplication = makeApplication(id: duplicateID)
        let secondApplication = makeApplication(id: duplicateID)
        let workspace = Workspace(
            name: "Study",
            symbol: "book",
            applications: [firstApplication, secondApplication]
        )
        let document = makeDocument(
            workspaces: [workspace]
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

    @Test("Duplicate bundle ID returns duplicateApplication error")
    func duplicateBundleIdentifierIsRejected() async throws {
        let bundleID = "com.apple.Safari"
        let duplicateBundleID = "   \(bundleID.uppercased())   \n"
        let firstApplication = makeApplication(bundleIdentifier: bundleID)
        let secondApplication = makeApplication(bundleIdentifier: duplicateBundleID)
        let workspace = Workspace(
            name: "Study",
            symbol: "book",
            applications: [firstApplication, secondApplication]
        )
        let document = makeDocument(
            workspaces: [workspace]
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

    @Test("Create workspace persists and caches the new workspace")
    func createWorkspacePersistsAndCaches() async throws {
        let repository = SettingsRepositorySpy()
        let sut = try await SettingsStore(repository: repository)
        let applications = makeApplication()

        let created = try await sut.createWorkspace(
            name: "Study",
            symbol: "book",
            applications: [applications]
        )

        let snapshot = await sut.snapshot()
        let savedDocuments = await repository.savedDocuments

        #expect(created.name == "Study")
        #expect(created.symbol == "book")
        #expect(created.applications == [applications])
        #expect(created.transition == .default)
        #expect(created.isArchived == false)
        #expect(snapshot.workspaces == [created])
        #expect(savedDocuments == [snapshot])
    }

    @Test("Create workspace persists the requested transition")
    func createWorkspacePersistsTransition() async throws {
        let repository = SettingsRepositorySpy()
        let sut = try await SettingsStore(repository: repository)
        let transition = WorkspaceTransition(
            activationPolicy: .close,
            terminalCommand: "echo close"
        )

        let created = try await sut.createWorkspace(
            name: "Focus",
            symbol: "target",
            transition: transition
        )

        let snapshot = await sut.snapshot()

        #expect(created.transition == transition)
        #expect(snapshot.workspaces == [created])
    }

    @Test("Create workspace does not save or modify cache when validation fails")
    func invalidCreateDoesNotMutate() async throws {
        let repository = SettingsRepositorySpy()
        let sut = try await SettingsStore(repository: repository)

        do {
            _ = try await sut.createWorkspace(
                name: " \n ",
                symbol: "book"
            )
            Issue.record("Expected creation to throw")
        } catch let error as SettingsStoreError {
            #expect(error == .emptyWorkspaceName)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let snapshot = await sut.snapshot()
        let savedDocuments = await repository.savedDocuments

        #expect(snapshot == .empty)
        #expect(savedDocuments.isEmpty)
    }

    @Test("Create workspace leaves cache unchanged when persistence fails")
    func failedCreateDoesNotMutate() async throws {
        let repository = SettingsRepositorySpy(
            saveError: TestError.saveFailed
        )
        let sut = try await SettingsStore(repository: repository)

        do {
            _ = try await sut.createWorkspace(
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

    @Test("Concurrent workspace creations preserve every workspace")
    func concurrentCreatesPreserveAllWorkspaces() async throws {
        let repository = SettingsRepositorySpy(
            yieldBeforeSaving: true
        )
        let sut = try await SettingsStore(repository: repository)
        let workspaceCount = 50

        try await withThrowingTaskGroup(of: Workspace.self) { group in
            for index in 0..<workspaceCount {
                group.addTask {
                    try await sut.createWorkspace(
                        name: "Workspace \(index)",
                        symbol: "square"
                    )
                }
            }

            for try await _ in group {}
        }

        let snapshot = await sut.snapshot()
        let storedDocument = await repository.storedDocument

        #expect(snapshot.workspaces.count == workspaceCount)
        #expect(Set(snapshot.workspaces.map(\.id)).count == workspaceCount)
        #expect(Set(snapshot.workspaces.map(\.name)).count == workspaceCount)
        #expect(storedDocument == snapshot)
    }

    @Test("Update workspace persists replacement while preserving order")
    func updateWorkspacePreservesOrder() async throws {
        let study = Workspace(
            name: "Study",
            symbol: "book"
        )
        let games = Workspace(
            name: "Games",
            symbol: "gamecontroller"
        )
        let initialDocument = makeDocument(
            workspaces: [study, games]
        )
        let repository = SettingsRepositorySpy(
            storedDocument: initialDocument
        )
        let sut = try await SettingsStore(repository: repository)

        let application = makeApplication()
        let updatedStudy = Workspace(
            id: study.id,
            name: "University",
            symbol: "graduationcap",
            applications: [application]
        )

        try await sut.updateWorkspace(updatedStudy)

        let snapshot = await sut.snapshot()
        let savedDocuments = await repository.savedDocuments

        #expect(snapshot.workspaces == [updatedStudy, games])
        #expect(savedDocuments == [snapshot])
    }

    @Test("Update workspace rejects an unknown identifier without saving")
    func unknownWorkspaceUpdateIsRejected() async throws {
        let existing = Workspace(
            name: "Study",
            symbol: "book"
        )
        let initialDocument = makeDocument(workspaces: [existing])
        let repository = SettingsRepositorySpy(
            storedDocument: initialDocument
        )
        let sut = try await SettingsStore(repository: repository)

        let unknown = Workspace(
            name: "Work",
            symbol: "briefcase"
        )

        do {
            try await sut.updateWorkspace(unknown)
            Issue.record("Expected update to throw")
        } catch let error as SettingsStoreError {
            #expect(error == .workspaceNotFound(unknown.id))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let snapshot = await sut.snapshot()
        let savedDocuments = await repository.savedDocuments

        #expect(snapshot == initialDocument)
        #expect(savedDocuments.isEmpty)
    }

    @Test("Update workspace leaves original unchanged when validation fails")
    func invalidUpdateDoesNotMutate() async throws {
        let existing = Workspace(
            name: "Study",
            symbol: "book"
        )
        let initialDocument = makeDocument(workspaces: [existing])
        let repository = SettingsRepositorySpy(
            storedDocument: initialDocument
        )
        let sut = try await SettingsStore(repository: repository)

        let invalidReplacement = Workspace(
            id: existing.id,
            name: " \n ",
            symbol: "book"
        )

        do {
            try await sut.updateWorkspace(invalidReplacement)
            Issue.record("Expected update to throw")
        } catch let error as SettingsStoreError {
            #expect(error == .emptyWorkspaceName)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(await sut.snapshot() == initialDocument)
        #expect(await repository.savedDocuments.isEmpty)
    }

    @Test("Update workspace leaves original unchanged when persistence fails")
    func failedUpdateDoesNotMutate() async throws {
        let existing = Workspace(
            name: "Study",
            symbol: "book"
        )
        let initialDocument = makeDocument(workspaces: [existing])
        let repository = SettingsRepositorySpy(
            storedDocument: initialDocument,
            saveError: TestError.saveFailed
        )
        let sut = try await SettingsStore(repository: repository)

        let replacement = Workspace(
            id: existing.id,
            name: "University",
            symbol: "graduationcap"
        )

        do {
            try await sut.updateWorkspace(replacement)
            Issue.record("Expected update to throw")
        } catch let error as TestError {
            #expect(error == .saveFailed)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(await sut.snapshot() == initialDocument)
        #expect(await repository.savedDocuments.isEmpty)
    }

    @Test("Delete workspace persists removal while preserving remaining order")
    func deleteWorkspacePreservesOrder() async throws {
        let study = Workspace(
            name: "Study",
            symbol: "book"
        )
        let games = Workspace(
            name: "Games",
            symbol: "gamecontroller"
        )
        let work = Workspace(
            name: "Work",
            symbol: "briefcase"
        )

        let initialDocument = makeDocument(
            workspaces: [study, games, work]
        )
        let repository = SettingsRepositorySpy(
            storedDocument: initialDocument
        )
        let sut = try await SettingsStore(repository: repository)

        try await sut.deleteWorkspace(id: games.id)

        let snapshot = await sut.snapshot()
        let savedDocuments = await repository.savedDocuments

        #expect(snapshot.workspaces == [study, work])
        #expect(savedDocuments == [snapshot])
    }

    @Test("Delete workspace rejects an unknown identifier without saving")
    func unknownWorkspaceDeleteIsRejected() async throws {
        let existing = Workspace(
            name: "Study",
            symbol: "book"
        )
        let initialDocument = makeDocument(workspaces: [existing])
        let repository = SettingsRepositorySpy(
            storedDocument: initialDocument
        )
        let sut = try await SettingsStore(repository: repository)
        let unknownID = UUID()

        do {
            try await sut.deleteWorkspace(id: unknownID)
            Issue.record("Expected deletion to throw")
        } catch let error as SettingsStoreError {
            #expect(error == .workspaceNotFound(unknownID))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(await sut.snapshot() == initialDocument)
        #expect(await repository.savedDocuments.isEmpty)
    }

    @Test("Delete workspace leaves original unchanged when persistence fails")
    func failedDeleteDoesNotMutate() async throws {
        let existing = Workspace(
            name: "Study",
            symbol: "book"
        )
        let initialDocument = makeDocument(workspaces: [existing])
        let repository = SettingsRepositorySpy(
            storedDocument: initialDocument,
            saveError: TestError.saveFailed
        )
        let sut = try await SettingsStore(repository: repository)

        do {
            try await sut.deleteWorkspace(id: existing.id)
            Issue.record("Expected deletion to throw")
        } catch let error as TestError {
            #expect(error == .saveFailed)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(await sut.snapshot() == initialDocument)
        #expect(await repository.savedDocuments.isEmpty)
    }

    @Test("Update settings persists launch at login without changing workspaces")
    func updateSettingsPreservesWorkspaces() async throws {
        let workspace = Workspace(
            name: "Study",
            symbol: "book"
        )
        let initialDocument = makeDocument(workspaces: [workspace])
        let repository = SettingsRepositorySpy(
            storedDocument: initialDocument
        )
        let sut = try await SettingsStore(repository: repository)

        try await sut.updateSettings(Settings(launchAtLogin: true))

        let snapshot = await sut.snapshot()
        let savedDocuments = await repository.savedDocuments

        #expect(snapshot.generalSettings.launchAtLogin)
        #expect(snapshot.workspaces == [workspace])
        #expect(savedDocuments == [snapshot])
    }

    @Test("Update settings supports enabling and disabling launch at login")
    func updateSettingsCanToggleLaunchAtLogin() async throws {
        let repository = SettingsRepositorySpy()
        let sut = try await SettingsStore(repository: repository)

        try await sut.updateSettings(Settings(launchAtLogin: true))
        try await sut.updateSettings(Settings(launchAtLogin: false))

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

    @Test("Failed settings update leaves the document unchanged")
    func failedUpdateSettingsDoesNotMutate() async throws {
        let initialDocument = SettingsDocument.empty
        let repository = SettingsRepositorySpy(
            storedDocument: initialDocument,
            saveError: TestError.saveFailed
        )
        let sut = try await SettingsStore(repository: repository)

        do {
            try await sut.updateSettings(Settings(launchAtLogin: true))
            Issue.record("Expected update to throw")
        } catch let error as TestError {
            #expect(error == .saveFailed)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(await sut.snapshot() == initialDocument)
        #expect(await repository.savedDocuments.isEmpty)
    }

    @Test("Update settings persists general settings without changing workspaces")
    func updateSettingsPersistsGeneralSettings() async throws {
        let workspace = Workspace(
            name: "Study",
            symbol: "book"
        )
        let initialDocument = makeDocument(workspaces: [workspace])
        let repository = SettingsRepositorySpy(
            storedDocument: initialDocument
        )
        let sut = try await SettingsStore(repository: repository)
        let settings = Settings(
            launchAtLogin: true,
            showInMenuBar: false,
            forceAppsToQuit: true,
            analyticsEnabled: true,
            protectedApps: [
                ProtectedApplication(
                    bundleIdentifier: "com.apple.Safari",
                    displayName: "Safari"
                )
            ]
        )

        try await sut.updateSettings(settings)

        let snapshot = await sut.snapshot()

        #expect(snapshot.generalSettings == settings)
        #expect(snapshot.workspaces == [workspace])
        #expect(await repository.savedDocuments == [snapshot])
    }

    @Test("Update settings accepts an empty protected app list")
    func updateSettingsAcceptsEmptyProtectedApps() async throws {
        let repository = SettingsRepositorySpy()
        let sut = try await SettingsStore(repository: repository)
        let settings = Settings(protectedApps: [])

        try await sut.updateSettings(settings)

        #expect(await sut.snapshot().generalSettings == settings)
    }

    @Test("Whitespace protected app name is rejected")
    func emptyProtectedAppNameIsRejected() async throws {
        let initialDocument = SettingsDocument.empty
        let repository = SettingsRepositorySpy(storedDocument: initialDocument)
        let sut = try await SettingsStore(repository: repository)

        do {
            try await sut.updateSettings(
                Settings(
                    protectedApps: [
                        ProtectedApplication(
                            bundleIdentifier: "com.apple.Safari",
                            displayName: " \n "
                        )
                    ]
                )
            )
            Issue.record("Expected update to throw")
        } catch let error as SettingsStoreError {
            #expect(error == .emptyApplicationDisplayName)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(await sut.snapshot() == initialDocument)
        #expect(await repository.savedDocuments.isEmpty)
    }

    @Test("Whitespace protected app bundle identifier is rejected")
    func emptyProtectedAppBundleIdentifierIsRejected() async throws {
        let initialDocument = SettingsDocument.empty
        let repository = SettingsRepositorySpy(storedDocument: initialDocument)
        let sut = try await SettingsStore(repository: repository)

        do {
            try await sut.updateSettings(
                Settings(
                    protectedApps: [
                        ProtectedApplication(
                            bundleIdentifier: " \n ",
                            displayName: "Safari"
                        )
                    ]
                )
            )
            Issue.record("Expected update to throw")
        } catch let error as SettingsStoreError {
            #expect(error == .emptyApplicationBundleIdentifier)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(await sut.snapshot() == initialDocument)
        #expect(await repository.savedDocuments.isEmpty)
    }

    @Test("Protected app bundle identifiers are rejected case-insensitively")
    func duplicateProtectedAppBundleIdentifierIsRejected() async throws {
        let initialDocument = SettingsDocument.empty
        let repository = SettingsRepositorySpy(storedDocument: initialDocument)
        let sut = try await SettingsStore(repository: repository)
        let duplicateBundleID = "  COM.APPLE.SAFARI \n"

        do {
            try await sut.updateSettings(
                Settings(
                    protectedApps: [
                        ProtectedApplication(
                            bundleIdentifier: "com.apple.Safari",
                            displayName: "Safari"
                        ),
                        ProtectedApplication(
                            bundleIdentifier: duplicateBundleID,
                            displayName: "Safari"
                        )
                    ]
                )
            )
            Issue.record("Expected update to throw")
        } catch let error as SettingsStoreError {
            #expect(error == .duplicateApplication(bundleIdentifier: duplicateBundleID))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(await sut.snapshot() == initialDocument)
        #expect(await repository.savedDocuments.isEmpty)
    }

    @Test("recording activation persists activity")
    func activationPersists() async throws {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )

        let repository = SettingsRepositorySpy(
            storedDocument: makeDocument(
                workspaces: [workspace]
            )
        )

        let store = try await SettingsStore(repository: repository)

        let activatedAt = Date(timeIntervalSince1970: 100)

        try await store.recordWorkspaceActivation(
            workspaceID: workspace.id,
            at: activatedAt
        )

        let snapshot = await store.snapshot()

        #expect(snapshot.workspaceActivity.activeWorkspaceID == workspace.id)
        #expect(snapshot.workspaceActivity.activeSince == activatedAt)
        #expect(await repository.savedDocuments == [snapshot])
    }

    @Test("stopping the active workspace persists its last-active time")
    func stoppingPersists() async throws {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )
        var document = makeDocument(
            workspaces: [workspace]
        )

        document.workspaceActivity.activate(
            workspaceID: workspace.id,
            at: Date(timeIntervalSince1970: 100)
        )

        let repository = SettingsRepositorySpy(
            storedDocument: document
        )
        let store = try await SettingsStore(
            repository: repository
        )
        let stoppedAt = Date(timeIntervalSince1970: 200)

        try await store.stopActiveWorkspace(at: stoppedAt)

        let snapshot = await store.snapshot()

        #expect(
            snapshot.workspaceActivity.activeWorkspaceID == nil
        )
        #expect(
            snapshot.workspaceActivity.lastActiveAt(
                for: workspace.id
            ) == stoppedAt
        )
    }

    @Test("deleting a workspace removes its activity metadata")
    func deletionRemovesActivity() async throws {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )
        var document = makeDocument(
            workspaces: [workspace]
        )

        document.workspaceActivity.activate(
            workspaceID: workspace.id,
            at: Date(timeIntervalSince1970: 100)
        )

        let repository = SettingsRepositorySpy(
            storedDocument: document
        )
        let store = try await SettingsStore(
            repository: repository
        )

        try await store.deleteWorkspace(id: workspace.id)

        let snapshot = await store.snapshot()

        #expect(snapshot.workspaces.isEmpty)
        #expect(snapshot.workspaceActivity == .empty)
    }

    @Test("unknown active ID throws workspaceNotFound")
    func unknownActiveIDThrowsError() async throws {
        let unknownID = UUID()
        let document = makeDocument(workspaces: [])

        let repository = SettingsRepositorySpy(storedDocument: document)

        let store = try await SettingsStore(repository: repository)

        await #expect(throws: SettingsStoreError.workspaceNotFound(unknownID)) {
            try await store.recordWorkspaceActivation(workspaceID: unknownID, at: Date(timeIntervalSince1970: 100))
        }

        #expect(await store.snapshot() == document)
        #expect(await repository.savedDocuments.isEmpty)
    }

    @Test("Failed persistence leaves cache unchanged")
    func failedPersistenceLeavesCacheUnchanged() async throws {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )

        let initialDocument = makeDocument(
            workspaces: [workspace]
        )

        let repository = SettingsRepositorySpy(
            storedDocument: initialDocument,
            saveError: TestError.saveFailed
        )

        let store = try await SettingsStore(repository: repository)

        await #expect(throws: TestError.saveFailed) {
            try await store.recordWorkspaceActivation(
                workspaceID: workspace.id,
                at: Date(timeIntervalSince1970: 100)
            )
        }

        #expect(await store.snapshot() == initialDocument)
        #expect(await repository.storedDocument == initialDocument)
        #expect(await repository.savedDocuments.isEmpty)
    }

    @Test("load retains active session for startup reconciliation")
    func loadRetainsActiveSessionForStartupReconciliation() async throws {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )
        let activeSince = Date(
            timeIntervalSince1970: 100
        )

        var document = makeDocument(
            workspaces: [workspace]
        )
        document.workspaceActivity.activate(
            workspaceID: workspace.id,
            at: activeSince
        )

        let repository = SettingsRepositorySpy(
            storedDocument: document
        )
        let store = try await SettingsStore(
            repository: repository
        )

        let snapshot = await store.snapshot()

        #expect(snapshot == document)
        #expect(
            snapshot.workspaceActivity.activeWorkspaceID
                == workspace.id
        )
        #expect(
            snapshot.workspaceActivity.activeSince
                == activeSince
        )

        #expect(
            await repository.savedDocuments.isEmpty
        )
    }

    @Test("startup removes orphaned activity")
    func startupRemovesOrphanedActivity() async throws {
        let retainedWorkspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )
        let orphanedWorkspaceID = UUID()
        let retainedLastActiveAt = Date(
            timeIntervalSince1970: 100
        )
        let orphanedLastActiveAt = Date(
            timeIntervalSince1970: 200
        )

        var document = makeDocument(
            workspaces: [retainedWorkspace]
        )
        document.workspaceActivity = WorkspaceActivityState(
            activeSession: .init(
                workspaceID: orphanedWorkspaceID,
                startedAt: Date(
                    timeIntervalSince1970: 300
                )
            ),
            lastActiveAtByWorkspaceID: [
                retainedWorkspace.id: retainedLastActiveAt,
                orphanedWorkspaceID: orphanedLastActiveAt,
            ]
        )

        let repository = SettingsRepositorySpy(
            storedDocument: document
        )
        let store = try await SettingsStore(
            repository: repository
        )

        let snapshot = await store.snapshot()

        #expect(
            snapshot.workspaceActivity.activeWorkspaceID == nil
        )
        #expect(
            snapshot.workspaceActivity.activeSince == nil
        )
        #expect(
            snapshot.workspaceActivity.lastActiveAt(
                for: retainedWorkspace.id
            ) == retainedLastActiveAt
        )
        #expect(
            snapshot.workspaceActivity.lastActiveAt(
                for: orphanedWorkspaceID
            ) == nil
        )

        #expect(
            await repository.savedDocuments == [snapshot]
        )
        #expect(
            await repository.storedDocument == snapshot
        )
    }

    @Test("Menu bar is visible by default")
    func menuBarIsVisibleByDefault() {
        #expect(Settings().showInMenuBar)
    }

    @Test("Legacy settings default menu bar visibility to true")
    func legacySettingsDefaultToVisible() throws {
        let data = Data(
            """
            {
            "launchAtLogin": false
            }
            """.utf8
        )

        let settings = try JSONDecoder().decode(
            Settings.self,
            from: data
        )

        #expect(settings.showInMenuBar)
    }

    @Test("Archive workspace persists the flag and preserves order")
    func archiveWorkspacePreservesOrder() async throws {
        let study = Workspace(name: "Study", symbol: "book")
        let games = Workspace(name: "Games", symbol: "gamecontroller")
        let work = Workspace(name: "Work", symbol: "briefcase")
        let repository = SettingsRepositorySpy(
            storedDocument: makeDocument(workspaces: [study, games, work])
        )
        let sut = try await SettingsStore(repository: repository)

        try await sut.archiveWorkspace(id: games.id)

        let archivedGames = Workspace(
            id: games.id,
            name: games.name,
            symbol: games.symbol,
            isArchived: true
        )
        let snapshot = await sut.snapshot()

        #expect(snapshot.workspaces == [study, archivedGames, work])
        #expect(await repository.savedDocuments == [snapshot])
    }

    @Test("Unarchive workspace clears the flag and preserves order")
    func unarchiveWorkspacePreservesOrder() async throws {
        let study = Workspace(name: "Study", symbol: "book")
        let games = Workspace(
            name: "Games",
            symbol: "gamecontroller",
            isArchived: true
        )
        let repository = SettingsRepositorySpy(
            storedDocument: makeDocument(workspaces: [study, games])
        )
        let sut = try await SettingsStore(repository: repository)

        try await sut.unarchiveWorkspace(id: games.id)

        let restoredGames = Workspace(
            id: games.id,
            name: games.name,
            symbol: games.symbol
        )
        let snapshot = await sut.snapshot()

        #expect(snapshot.workspaces == [study, restoredGames])
        #expect(await repository.savedDocuments == [snapshot])
    }

    @Test("Archive and unarchive reject an unknown identifier without saving")
    func unknownWorkspaceArchiveIsRejected() async throws {
        let existing = Workspace(name: "Study", symbol: "book")
        let initialDocument = makeDocument(workspaces: [existing])
        let repository = SettingsRepositorySpy(storedDocument: initialDocument)
        let sut = try await SettingsStore(repository: repository)
        let unknownID = UUID()

        do {
            try await sut.archiveWorkspace(id: unknownID)
            Issue.record("Expected archive to throw")
        } catch let error as SettingsStoreError {
            #expect(error == .workspaceNotFound(unknownID))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        do {
            try await sut.unarchiveWorkspace(id: unknownID)
            Issue.record("Expected unarchive to throw")
        } catch let error as SettingsStoreError {
            #expect(error == .workspaceNotFound(unknownID))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(await sut.snapshot() == initialDocument)
        #expect(await repository.savedDocuments.isEmpty)
    }

    @Test("Repeating archive or unarchive does not save again")
    func repeatedArchiveDoesNotSave() async throws {
        let study = Workspace(name: "Study", symbol: "book")
        let repository = SettingsRepositorySpy(
            storedDocument: makeDocument(workspaces: [study])
        )
        let sut = try await SettingsStore(repository: repository)

        try await sut.unarchiveWorkspace(id: study.id)
        try await sut.archiveWorkspace(id: study.id)
        try await sut.archiveWorkspace(id: study.id)

        let savedDocuments = await repository.savedDocuments
        #expect(savedDocuments.count == 1)
        #expect(savedDocuments[0].workspaces.map(\.isArchived) == [true])

        try await sut.unarchiveWorkspace(id: study.id)
        try await sut.unarchiveWorkspace(id: study.id)

        #expect(await repository.savedDocuments.count == 2)
        #expect(await sut.snapshot().workspaces.map(\.isArchived) == [false])
    }

    @Test("Update workspace preserves archival state")
    func updateWorkspacePreservesArchivalState() async throws {
        let study = Workspace(
            name: "Study",
            symbol: "book",
            isArchived: true
        )
        let games = Workspace(name: "Games", symbol: "gamecontroller")
        let repository = SettingsRepositorySpy(
            storedDocument: makeDocument(workspaces: [study, games])
        )
        let sut = try await SettingsStore(repository: repository)

        let updatedStudy = Workspace(
            id: study.id,
            name: "University",
            symbol: "graduationcap"
        )
        let archivedGames = Workspace(
            id: games.id,
            name: "Play",
            symbol: "briefcase.fill",
            isArchived: true
        )

        try await sut.updateWorkspace(updatedStudy)
        try await sut.updateWorkspace(archivedGames)

        let snapshot = await sut.snapshot()
        #expect(snapshot.workspaces.map(\.name) == ["University", "Play"])
        #expect(snapshot.workspaces.map(\.isArchived) == [true, false])
    }

    @Test("Delete workspace removes an archived workspace")
    func deleteArchivedWorkspace() async throws {
        let study = Workspace(name: "Study", symbol: "book")
        let archived = Workspace(
            name: "Old",
            symbol: "archivebox",
            isArchived: true
        )
        let repository = SettingsRepositorySpy(
            storedDocument: makeDocument(workspaces: [study, archived])
        )
        let sut = try await SettingsStore(repository: repository)

        try await sut.deleteWorkspace(id: archived.id)

        let snapshot = await sut.snapshot()
        #expect(snapshot.workspaces == [study])
        #expect(await repository.savedDocuments == [snapshot])
    }

    @Test("Archive workspace leaves the cache unchanged when persistence fails")
    func failedArchiveDoesNotMutate() async throws {
        let existing = Workspace(name: "Study", symbol: "book")
        let initialDocument = makeDocument(workspaces: [existing])
        let repository = SettingsRepositorySpy(
            storedDocument: initialDocument,
            saveError: TestError.saveFailed
        )
        let sut = try await SettingsStore(repository: repository)

        do {
            try await sut.archiveWorkspace(id: existing.id)
            Issue.record("Expected archive to throw")
        } catch let error as TestError {
            #expect(error == .saveFailed)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(await sut.snapshot() == initialDocument)
        #expect(await repository.savedDocuments.isEmpty)
    }

    @Test("Archiving the active workspace clears the active session")
    func archiveClearsActiveSession() async throws {
        let study = Workspace(name: "Study", symbol: "book")
        var document = makeDocument(workspaces: [study])
        document.workspaceActivity.activate(
            workspaceID: study.id,
            at: Date(timeIntervalSince1970: 100)
        )
        let repository = SettingsRepositorySpy(storedDocument: document)
        let sut = try await SettingsStore(repository: repository)

        try await sut.archiveWorkspace(id: study.id)

        let snapshot = await sut.snapshot()
        #expect(snapshot.workspaceActivity.activeWorkspaceID == nil)
        #expect(snapshot.workspaces.map(\.isArchived) == [true])
    }

    private func makeDocument(
        workspaces: [Workspace]
    ) -> SettingsDocument {
        SettingsDocument(
            schemaVersion: SettingsDocument.currentSchemaVersion,
            workspaces: workspaces,
            generalSettings: Settings()
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
