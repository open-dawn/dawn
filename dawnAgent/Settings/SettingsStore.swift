//
//  SettingsStore.swift
//  dawn
//
//  Created by Rafael Venetikides on 20/08/26.
//

import Foundation
import dawnLogging
import libdawn

actor SettingsStore {
    private let repository: any SettingsRepository
    private var document: SettingsDocument
    private var mutationInProgress = false
    private var mutationWaiters: [CheckedContinuation<Void, Never>] = []

    static func make(repository: any SettingsRepository) async throws -> SettingsStore {
        do {
            return try await SettingsStore(repository: repository)
        } catch {
            #log(
                "Corrupted SettingsStore \(error.localizedDescription)",
                level: .error,
                category: .settings
            )
            #log("Reseting setting store", level: .info, category: .settings)

            try await repository.save(.empty)
            return try await SettingsStore(repository: repository)
        }
    }

    init(repository: any SettingsRepository) async throws {
        var document = try await repository.load() ?? .empty
        let loadedDocument = document

        document.workspaceActivity.reconcile(
            validWorkspaceIDs: Set(
                document.workspaces.map(
                    \.id
                )
            )
        )

        try Self.validate(document)

        if document != loadedDocument {
            try await repository.save(document)
        }

        self.repository = repository
        self.document = document
    }

    func snapshot() -> SettingsDocument {
        document
    }

    func createWorkspace(
        name: String,
        symbol: String,
        applications: [WorkspaceApplication] = [],
        transition: WorkspaceTransition = .default
    ) async throws -> Workspace {
        let newWorkspace = Workspace(
            name: name,
            symbol: symbol,
            applications: applications,
            transition: transition
        )

        return try await mutate { candidate in
            candidate.workspaces.append(newWorkspace)
            return newWorkspace
        }
    }

    func updateWorkspace(
        _ updatedWorkspace: Workspace
    ) async throws {
        try await mutate { candidate in
            guard
                let workspaceIndex = candidate.workspaces.firstIndex(
                    where: { $0.id == updatedWorkspace.id }
                )
            else {
                throw SettingsStoreError.workspaceNotFound(
                    updatedWorkspace.id
                )
            }

            var replacement = updatedWorkspace
            replacement.isArchived = candidate.workspaces[workspaceIndex].isArchived
            candidate.workspaces[workspaceIndex] = replacement
        }
    }

    func archiveWorkspace(id: UUID) async throws {
        try await setArchived(true, id: id)
    }

    func unarchiveWorkspace(id: UUID) async throws {
        try await setArchived(false, id: id)
    }

    func deleteWorkspace(
        id: UUID
    ) async throws {
        try await mutate { candidate in
            guard
                let workspaceIndex = candidate.workspaces.firstIndex(
                    where: { $0.id == id }
                )
            else {
                throw SettingsStoreError.workspaceNotFound(
                    id
                )
            }

            candidate.workspaces.remove(at: workspaceIndex)
            candidate.workspaceActivity.removeWorkspace(id: id)
        }
    }

    private func setArchived(_ isArchived: Bool, id: UUID) async throws {
        await acquireMutationAccess()
        defer { releaseMutationAccess() }

        try Task.checkCancellation()

        guard let index = document.workspaces.firstIndex(where: { $0.id == id }) else {
            throw SettingsStoreError.workspaceNotFound(id)
        }

        guard document.workspaces[index].isArchived != isArchived else {
            return
        }

        var candidate = document
        candidate.workspaces[index].isArchived = isArchived

        if isArchived, candidate.workspaceActivity.activeWorkspaceID == id {
            candidate.workspaceActivity.clearActiveSession(for: id)
        }

        try Self.validate(candidate)
        try await repository.save(candidate)

        document = candidate
    }

    func updateSettings(_ settings: Settings) async throws {
        try await mutate { candidate in
            candidate.generalSettings = settings
        }
    }

    private func acquireMutationAccess() async {
        guard mutationInProgress else {
            mutationInProgress = true
            return
        }

        await withCheckedContinuation { continuation in
            mutationWaiters.append(continuation)
        }
    }

    private func releaseMutationAccess() {
        guard !mutationWaiters.isEmpty else {
            mutationInProgress = false
            return
        }

        mutationWaiters.removeFirst().resume()
    }

    @discardableResult
    func recordWorkspaceActivation(
        workspaceID: UUID,
        at date: Date
    ) async throws -> WorkspaceActivityState {
        try await mutate { candidate in
            guard candidate.workspaces.contains(where: { $0.id == workspaceID }) else {
                throw SettingsStoreError.workspaceNotFound(workspaceID)
            }

            candidate.workspaceActivity.activate(
                workspaceID: workspaceID,
                at: date
            )

            return candidate.workspaceActivity
        }
    }

    @discardableResult
    func stopActiveWorkspace(at date: Date) async throws -> WorkspaceActivityState {
        try await mutate { candidate in
            candidate.workspaceActivity.stop(at: date)
            return candidate.workspaceActivity
        }
    }

    private func mutate<Result: Sendable>(
        _ mutation: (inout SettingsDocument) throws -> Result
    ) async throws -> Result {
        await acquireMutationAccess()
        defer { releaseMutationAccess() }

        try Task.checkCancellation()

        var candidate = document
        let result = try mutation(&candidate)

        try Self.validate(candidate)
        try await repository.save(candidate)

        document = candidate
        return result
    }

    func generalSettings() -> Settings {
        document.generalSettings
    }
}
