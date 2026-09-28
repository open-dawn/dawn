import Foundation
import libdawn
import dawnLogging

final class ContextManager: ContextProviding {
    private let store: SettingsStore
    private let snapshotPublisher: ContextSnapshotPublishing

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
        let storeSnapshot = await store.snapshot()
        return storeSnapshot.contexts
    }

    func createContext(name: String, symbol: String, applications: [WorkspaceApplication]) async throws
        -> WorkspaceContext
    {
        let context = try await store.createContext(name: name, symbol: symbol, applications: applications)

        await publishAvailableContexts()
        return context
    }

    func getContext(id: UUID) async -> WorkspaceContext? {
        let contexts = await getAvailableContexts()
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

    private func publishAvailableContexts() async {
        let snapshot = await store.snapshot()
        snapshotPublisher.publishAvailableContexts(snapshot.contexts)
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

    func getContext(id: UUID) async -> WorkspaceContext?
}
