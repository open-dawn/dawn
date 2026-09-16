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

    func createContext(context: WorkspaceContext) async throws -> WorkspaceContext {
        try await store.createContext(name: context.name, symbol: context.symbol, applications: context.applications)
    }

    func getContext(uuid: UUID) async -> WorkspaceContext? {
        let contexts = await getAvailableContexts()
        return contexts.first(where: { $0.id == uuid })
    }

    func updateContext(context: WorkspaceContext) async throws {
        try await store.updateContext(context)
    }

    func deleteContext(uuid: UUID) async throws {
        try await store.deleteContext(id: uuid)
    }
}

protocol ContextProviding {
    func getAvailableContexts() async -> [WorkspaceContext]
}