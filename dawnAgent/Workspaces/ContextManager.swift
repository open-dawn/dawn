import Foundation
import libdawn
import dawnLogging

final class ContextManager: WorkspaceManaging {
    private let store: SettingsStore
    private let snapshotPublisher: ContextSnapshotPublishing

    var menuBarVisibilityStore: any MenuBarVisibilityStoring {
        store
    }

    init(
        repository: any SettingsRepository = UserDefaultsSettingsRepository(),
        snapshotPublisher: ContextSnapshotPublishing
    ) async throws {
        self.snapshotPublisher = snapshotPublisher

        do {
            store = try await SettingsStore(repository: repository)
        } catch {
            #log("Corrupted SettingsStore \(error.localizedDescription)", level: .error, category: .settings)
            #log("Reseting setting store", level: .info, category: .settings)

            try await repository.save(.empty)
            store = try await SettingsStore(repository: repository)
        }
    }

    func getAvailableContexts() async -> [WorkspaceContext] {
        await store.snapshot().contexts
    }

    func getWorkspaceSnapshot() async -> WorkspaceSnapshot {
        let document = await store.snapshot()

        return WorkspaceSnapshot(
            contexts: document.contexts,
            activity: document.workspaceActivity
        )
    }

    func createContext(name: String, symbol: String, applications: [WorkspaceApplication]) async throws
        -> WorkspaceContext
    {
        let context = try await store.createContext(name: name, symbol: symbol, applications: applications)

        await publishAvailableContexts()
        return context
    }

    func getContext(id: UUID) async -> WorkspaceContext? {
        let contexts = await store.snapshot().contexts
        return contexts.first(where: { $0.id == id })
    }

    func updateContext(_ context: WorkspaceContext) async throws {
        try await store.updateContext(context)
        await publishAvailableContexts()
    }

    func deleteContext(id: UUID) async throws {
        try await store.deleteContext(id: id)
        await publishAvailableContexts()
    }

    func archiveContext(id: UUID) async throws {
        try await store.archiveContext(id: id)
        await publishAvailableContexts()
    }

    func unarchiveContext(id: UUID) async throws {
        try await store.unarchiveContext(id: id)
        await publishAvailableContexts()
    }

    private func publishAvailableContexts() async {
        let contexts = await store.snapshot().contexts
        snapshotPublisher.publishAvailableContexts(contexts)
    }

    func getWorkspaceActivity() async -> WorkspaceActivityState {
        let snapshot = await store.snapshot()

        return snapshot.workspaceActivity
    }

    @discardableResult
    func recordContextActivation(contextID: UUID, at date: Date) async throws -> WorkspaceActivityState {
        try await store.recordContextActivation(contextID: contextID, at: date)
    }

    @discardableResult
    func stopActiveContext(at date: Date) async throws -> WorkspaceActivityState {
        try await store.stopActiveContext(at: date)
    }
}

@MainActor
protocol ContextProviding {
    func getAvailableContexts() async -> [WorkspaceContext]

    func createContext(
        name: String,
        symbol: String,
        applications: [WorkspaceApplication]
    ) async throws -> WorkspaceContext

    func updateContext(_ context: WorkspaceContext) async throws

    func deleteContext(id: UUID) async throws

    func archiveContext(id: UUID) async throws

    func unarchiveContext(id: UUID) async throws

    func getContext(id: UUID) async -> WorkspaceContext?
}
