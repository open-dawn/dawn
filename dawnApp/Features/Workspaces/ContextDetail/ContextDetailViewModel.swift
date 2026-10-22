import Foundation
import libdawn

@Observable
@MainActor
final class ContextDetailViewModel {
    private let contextManager: any WorkspaceContextManaging

    private(set) var operationInProgress: UUID?
    private(set) var activeContextID: UUID?
    private(set) var error: SettingsContextStoreError?
    private(set) var contextBeingEdited: WorkspaceContext?
    var isCreatingOrEditing: Bool

    init(contextManager: any WorkspaceContextManaging) {
        self.contextManager = contextManager
        isCreatingOrEditing = false
    }

    func presentContextCreator() {
        contextBeingEdited = nil
        isCreatingOrEditing = true
    }

    func presentContextEditor(_ context: WorkspaceContext) {
        contextBeingEdited = context
        isCreatingOrEditing = true
    }

    func dismissContextCreator() {
        isCreatingOrEditing = false
        contextBeingEdited = nil
    }

    func dismissError() {
        error = nil
    }

    func reconcileActiveContext(with contexts: [WorkspaceContext]) {
        guard let activeContextID else {
            return
        }

        let stillExists = contexts.contains { $0.id == activeContextID }
        if !stillExists {
            self.activeContextID = nil
        }
    }

    func runContext(_ context: WorkspaceContext) async {
        guard operationInProgress == nil else { return }

        operationInProgress = context.id
        defer { operationInProgress = nil }

        do {
            try await contextManager.switchContext(id: context.id)
            activeContextID = context.id
            error = nil
        } catch let error as SettingsContextStoreError {
            self.error = error
        } catch {
            self.error = .unknown
        }
    }

    func deleteContext(_ context: WorkspaceContext) async {
        guard operationInProgress == nil else { return }

        operationInProgress = context.id
        defer { operationInProgress = nil }

        do {
            try await contextManager.deleteContext(id: context.id)
            if activeContextID == context.id {
                activeContextID = nil
            }
            error = nil
        } catch let error as SettingsContextStoreError {
            self.error = error
        } catch {
            self.error = .unknown
        }
    }
}
