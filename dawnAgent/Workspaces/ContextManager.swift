import Foundation
import libdawn

final class ContextManager: WorkspaceManaging {
    private let store: SettingsStore
    private let snapshotPublisher: ContextSnapshotPublishing

    var menuBarVisibilityStore: any MenuBarVisibilityStoring {
        store
    }

    init(
        store: SettingsStore,
        snapshotPublisher: ContextSnapshotPublishing
    ) {
        self.store = store
        self.snapshotPublisher = snapshotPublisher
    }

    func getAvailableContexts() async -> [WorkspaceContext] {
        let storeSnapshot = await store.snapshot()
        return storeSnapshot.contexts
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
    func getContext(id: UUID) async -> WorkspaceContext?
}
