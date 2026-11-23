//
//  MenuBarWorkspaceListViewModel.swift
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
final class MenuBarWorkspaceListViewModel {
    private enum Operation: Equatable {
        case activating(UUID)
        case opening(DawnAppRoute)
        case stopping(UUID)
        case deleting(UUID)
    }

    let runtime: WorkspaceRuntime

    private let openApp: (DawnAppRoute) async throws -> Void

    private var operation: Operation?

    private(set) var errorMessage: String?
    private(set) var workspacePendingDeletion: Workspace?

    init(workspace runtime: WorkspaceRuntime, openApp: @escaping (DawnAppRoute) async throws -> Void) {
        self.runtime = runtime
        self.openApp = openApp
    }

    var activeWorkspace: Workspace? {
        guard let activeWorkspaceID = runtime.activeWorkspaceID else {
            return nil
        }

        return runtime.workspaces.first {
            $0.id == activeWorkspaceID && !$0.isArchived
        }
    }

    var inactiveWorkspaces: [Workspace] {
        runtime.workspaces.filter {
            !$0.isArchived && $0.id != runtime.activeWorkspaceID
        }
    }

    var isPerformingOperation: Bool {
        operation != nil
    }

    func isLoading(_ workspace: Workspace) -> Bool {
        switch operation {
        case .activating(let workspaceID):
            workspaceID == workspace.id

        case .opening(.workspace(let workspaceID)):
            workspaceID == workspace.id

        case .stopping(let workspaceID):
            workspaceID == workspace.id

        case .deleting(let workspaceID):
            workspaceID == workspace.id

        case .opening, nil:
            false
        }
    }

    func select(_ workspace: Workspace) async {
        guard runtime.activeWorkspaceID != workspace.id else {
            return
        }

        await activate(workspace)
    }

    func handle(_ action: WorkspaceCardAction, for workspace: Workspace) async {
        switch action {
        case .activate:
            await activate(workspace)

        case .openInApp:
            await open(.workspace(workspace.id))

        case .stop:
            await stop(workspace)

        case .delete:
            requestDeletion(of: workspace)
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

    func requestDeletion(of workspace: Workspace) {
        guard !isPerformingOperation else {
            return
        }

        workspacePendingDeletion = workspace
    }

    func cancelDeletion() {
        workspacePendingDeletion = nil
    }

    func confirmDeletion(of workspace: Workspace) async {
        workspacePendingDeletion = nil

        await delete(workspace)
    }

    func dismissError() {
        errorMessage = nil
    }

    private func activate(_ workspace: Workspace) async {
        guard !isPerformingOperation, runtime.activeWorkspaceID != workspace.id else {
            return
        }

        operation = .activating(workspace.id)
        errorMessage = nil

        defer { operation = nil }

        do {
            try await runtime.activateWorkspace(id: workspace.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func stop(_ workspace: Workspace) async {
        guard !isPerformingOperation, runtime.activeWorkspaceID == workspace.id else {
            return
        }

        operation = .stopping(workspace.id)
        errorMessage = nil

        defer { operation = nil }

        do {
            try await runtime.stopActiveWorkspace()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ workspace: Workspace) async {
        guard !isPerformingOperation else {
            return
        }

        operation = .deleting(workspace.id)
        errorMessage = nil

        defer { operation = nil }

        do {
            try await runtime.deleteWorkspace(id: workspace.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
