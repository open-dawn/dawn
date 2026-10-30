//
//  MenuBarContextListViewModel.swift
//  dawn
//
//  Created by Rafael Venetikides on 29/10/26.
//

import Foundation
import Observation
import libdawn
import libdawnUI

@Observable
@MainActor
final class MenuBarContextListViewModel {
    private enum Operation: Equatable {
        case activating(UUID)
        case opening(DawnAppRoute)
        case stopping(UUID)
        case deleting(UUID)
    }

    let workspace: WorkspaceRuntime

    private let openApp: (DawnAppRoute) async throws -> Void

    private var operation: Operation?

    private(set) var errorMessage: String?
    private(set) var contextPendingDeletion: WorkspaceContext?

    init(workspace: WorkspaceRuntime, openApp: @escaping (DawnAppRoute) async throws -> Void) {
        self.workspace = workspace
        self.openApp = openApp
    }

    var activeContext: WorkspaceContext? {
        guard let activeContextID = workspace.activeContextID else {
            return nil
        }

        return workspace.contexts.first {
            $0.id == activeContextID && !$0.isArchived
        }
    }

    var inactiveContexts: [WorkspaceContext] {
        workspace.contexts.filter {
            !$0.isArchived && $0.id != workspace.activeContextID
        }
    }

    var isPerformingOperation: Bool {
        operation != nil
    }

    func isLoading(_ context: WorkspaceContext) -> Bool {
        switch operation {
        case .activating(let contextID):
            contextID == context.id

        case .opening(.context(let contextID)):
            contextID == context.id

        case .stopping(let contextID):
            contextID == context.id

        case .deleting(let contextID):
            contextID == context.id

        case .opening, nil:
            false
        }
    }

    func select(_ context: WorkspaceContext) async {
        guard workspace.activeContextID != context.id else {
            return
        }

        await activate(context)
    }

    func handle(_ action: ContextCardAction, for context: WorkspaceContext) async {
        switch action {
        case .activate:
            await activate(context)

        case .openInApp:
            await open(.context(context.id))

        case .stop:
            await stop(context)

        case .delete:
            requestDeletion(of: context)
        }
    }

    func open(_ route: DawnAppRoute) async {
        guard !isPerformingOperation else {
            return
        }

        operation = .opening(route)
        errorMessage = nil

        defer { operation = nil }

        do {
            try await openApp(route)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestDeletion(of context: WorkspaceContext) {
        guard !isPerformingOperation else {
            return
        }

        contextPendingDeletion = context
    }

    func cancelDeletion() {
        contextPendingDeletion = nil
    }

    func confirmDeletion(of context: WorkspaceContext) async {
        contextPendingDeletion = nil

        await delete(context)
    }

    func dismissError() {
        errorMessage = nil
    }

    private func activate(_ context: WorkspaceContext) async {
        guard !isPerformingOperation, workspace.activeContextID != context.id else {
            return
        }

        operation = .activating(context.id)
        errorMessage = nil

        defer { operation = nil }

        do {
            try await workspace.activateContext(id: context.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func stop(_ context: WorkspaceContext) async {
        guard !isPerformingOperation, workspace.activeContextID == context.id else {
            return
        }

        operation = .stopping(context.id)
        errorMessage = nil

        defer { operation = nil }

        do {
            try await workspace.stopActiveContext()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ context: WorkspaceContext) async {
        guard !isPerformingOperation else {
            return
        }

        operation = .deleting(context.id)
        errorMessage = nil

        defer { operation = nil }

        do {
            try await workspace.deleteContext(id: context.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
