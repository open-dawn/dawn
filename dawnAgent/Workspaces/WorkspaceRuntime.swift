//
//  WorkspaceRuntime.swift
//  dawn
//
//  Created by Rafael Venetikides on 06/10/26.
//

import Foundation
import Observation
import libdawn

@MainActor
protocol WorkspaceCoordinating: ContextProviding {
    var contexts: [WorkspaceContext] { get }
    var lastRequestedContextID: UUID? { get }

    func refresh() async
    func activateContext(id: UUID) async throws
}

@Observable
@MainActor
final class WorkspaceRuntime: WorkspaceCoordinating {
    private let contextManager: any ContextProviding
    private let contextSwitching: any ContextSwitching

    @ObservationIgnored
    private var refreshGeneration: UInt = 0

    private(set) var contexts: [WorkspaceContext] = []
    private(set) var lastRequestedContextID: UUID?

    init(contextManager: any ContextProviding, contextSwitching: any ContextSwitching = DefaultContextSwitching()) {
        self.contextManager = contextManager
        self.contextSwitching = contextSwitching
    }

    func refresh() async {
        refreshGeneration &+= 1
        let generation = refreshGeneration

        let snapshot = await contextManager.getAvailableContexts()

        guard generation == refreshGeneration else {
            return
        }

        contexts = snapshot

        if let lastRequestedContextID, !snapshot.contains(where: { $0.id == lastRequestedContextID }) {
            self.lastRequestedContextID = nil
        }
    }

    func getAvailableContexts() async -> [WorkspaceContext] {
        await refresh()
        return contexts
    }

    func getContext(id: UUID) async -> WorkspaceContext? {
        await contextManager.getContext(id: id)
    }

    func createContext(
        name: String,
        symbol: String,
        applications: [WorkspaceApplication]
    ) async throws -> WorkspaceContext {
        let context = try await contextManager.createContext(name: name, symbol: symbol, applications: applications)

        await refresh()
        return context
    }

    func updateContext(_ context: WorkspaceContext) async throws {
        try await contextManager.updateContext(context)
        await refresh()
    }

    func deleteContext(id: UUID) async throws {
        try await contextManager.deleteContext(id: id)
        await refresh()
    }

    func activateContext(id: UUID) async throws {
        guard let context = await contextManager.getContext(id: id) else {
            throw SettingsStoreError.contextNotFound(id)
        }

        contextSwitching.switchToContext(to: context)
        lastRequestedContextID = context.id
    }
}
