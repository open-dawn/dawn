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
    var workspaceActivity: WorkspaceActivityState { get }
    var activeContextID: UUID? { get }
    var activeSince: Date? { get }

    func refresh() async
    func activateContext(id: UUID) async throws
    func stopActiveContext() async throws
}

@Observable
@MainActor
final class WorkspaceRuntime: WorkspaceCoordinating {
    private let contextManager: any WorkspaceManaging
    private let contextSwitching: any ContextSwitching
    private let clock: any WorkspaceClock

    @ObservationIgnored
    private var refreshGeneration: UInt = 0

    private(set) var contexts: [WorkspaceContext] = []
    private(set) var workspaceActivity: WorkspaceActivityState = .empty

    var activeContextID: UUID? {
        workspaceActivity.activeContextID
    }

    var activeSince: Date? {
        workspaceActivity.activeSince
    }

    init(
        contextManager: any WorkspaceManaging,
        contextSwitching: any ContextSwitching = DefaultContextSwitching(),
        clock: any WorkspaceClock = SystemWorkspaceClock()
    ) {
        self.contextManager = contextManager
        self.contextSwitching = contextSwitching
        self.clock = clock
    }

    func refresh() async {
        refreshGeneration &+= 1
        let generation = refreshGeneration

        let snapshot = await contextManager.getWorkspaceSnapshot()

        guard generation == refreshGeneration else {
            return
        }

        contexts = snapshot.contexts
        workspaceActivity = snapshot.activity
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

    func archiveContext(id: UUID) async throws {
        try await contextManager.archiveContext(id: id)
        await refresh()
    }

    func unarchiveContext(id: UUID) async throws {
        try await contextManager.unarchiveContext(id: id)
        await refresh()
    }

    func activateContext(id: UUID) async throws {
        guard let context = await contextManager.getContext(id: id) else {
            throw SettingsStoreError.contextNotFound(id)
        }

        guard !context.isArchived else {
            throw SettingsStoreError.contextArchived(id)
        }

        try await contextSwitching.switchToContext(to: context)

        workspaceActivity = try await contextManager.recordContextActivation(
            contextID: context.id,
            at: clock.now
        )
    }

    func stopActiveContext() async throws {
        workspaceActivity = try await contextManager.stopActiveContext(at: clock.now)
    }

    func lastActiveAt(for contextID: UUID) -> Date? {
        workspaceActivity.lastActiveAt(for: contextID)
    }
}
