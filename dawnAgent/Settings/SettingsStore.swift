//
//  SettingsStore.swift
//  pineapplewm
//
//  Created by Rafael Venetikides on 20/08/26.
//

import Foundation
import libdawn

actor SettingsStore {
    private let repository: any SettingsRepository
    private var document: SettingsDocument
    private var mutationInProgress = false
    private var mutationWaiters: [CheckedContinuation<Void, Never>] = []

    init(repository: any SettingsRepository) async throws {
        let document = try await repository.load() ?? .empty

        try Self.validate(document)

        self.repository = repository
        self.document = document
    }

    func snapshot() -> SettingsDocument {
        document
    }

    func createContext(
        name: String,
        symbol: String,
        applications: [WorkspaceApplication] = []
    ) async throws -> WorkspaceContext {
        let newContext = WorkspaceContext(
            name: name,
            symbol: symbol,
            applications: applications
        )

        return try await mutate { candidate in
            candidate.contexts.append(newContext)
            return newContext
        }
    }

    func updateContext(
        _ updatedContext: WorkspaceContext
    ) async throws {
        try await mutate { candidate in
            guard let contextIndex = candidate.contexts.firstIndex(
                where: { $0.id == updatedContext.id }
            ) else {
                throw SettingsStoreError.contextNotFound(
                    updatedContext.id
                )
            }

            candidate.contexts[contextIndex] = updatedContext
        }
    }

    func deleteContext(
        id: UUID
    ) async throws {
        try await mutate { candidate in
            guard let contextIndex = candidate.contexts.firstIndex(
                where: { $0.id == id }
            ) else {
                throw SettingsStoreError.contextNotFound(
                    id
                )
            }

            candidate.contexts.remove(at: contextIndex)
        }
    }

    func setLaunchAtLogin(
        _ enabled: Bool
    ) async throws {
        try await mutate { candidate in
            candidate.generalSettings.launchAtLogin = enabled
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

    private static func validate(_ document: SettingsDocument) throws {
        var contextIdentifiers = Set<UUID>()

        for context in document.contexts {
            guard contextIdentifiers.insert(context.id).inserted else {
                throw SettingsStoreError.duplicateContextIdentifier(context.id)
            }

            try validate(context)
        }
    }

    private static func validate(_ context: WorkspaceContext) throws {
        let trimmedName = context.name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmedName.isEmpty else {
            throw SettingsStoreError.emptyContextName
        }

        let trimmedSymbol = context.symbol.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmedSymbol.isEmpty else {
            throw SettingsStoreError.emptyContextSymbol
        }

        var applicationIdentifiers = Set<UUID>()
        var bundleIdentifiers = Set<String>()

        for application in context.applications {
            try validate(application)

            guard applicationIdentifiers.insert(application.id).inserted else {
                throw SettingsStoreError.duplicateApplicationIdentifier(
                    application.id
                )
            }

            let normalizedBundleIdentifier = application.bundleIdentifier
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            guard bundleIdentifiers.insert(normalizedBundleIdentifier).inserted else {
                throw SettingsStoreError.duplicateApplication(
                    bundleIdentifier: application.bundleIdentifier
                )
            }
        }
    }

    private static func validate(_ application: WorkspaceApplication) throws {
        let trimmedBundleIdentifier = application.bundleIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedBundleIdentifier.isEmpty else {
            throw SettingsStoreError.emptyApplicationBundleIdentifier
        }

        let trimmedDisplayName = application.displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedDisplayName.isEmpty else {
            throw SettingsStoreError.emptyApplicationDisplayName
        }
    }
}
