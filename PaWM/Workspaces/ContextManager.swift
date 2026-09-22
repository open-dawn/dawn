import Foundation
import PaEventKit
import PaLogging

final class ContextManager: ContextProviding {
    private let store: SettingsStore

    init(repository: any SettingsRepository = UserDefaultsSettingsRepository()) async throws {
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

    func createContext(name: String, symbol: String, applications: [WorkspaceApplication]) async throws -> WorkspaceContext {
        try await store.createContext(name: name, symbol: symbol, applications: applications)
    }

    func getContext(id: UUID) async -> WorkspaceContext? {
        let contexts = await getAvailableContexts()
        return contexts.first(where: { $0.id == id })
    }

    func updateContext(_ context: WorkspaceContext) async throws {
        try await store.updateContext(context)
    }

    func deleteContext(id: UUID) async throws {
        try await store.deleteContext(id: id)
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
