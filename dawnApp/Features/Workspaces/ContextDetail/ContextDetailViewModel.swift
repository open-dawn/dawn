import Foundation
import libdawn

extension ContextDetailView {
    @Observable
    @MainActor
    class ViewModel {
        private let contextManager: any WorkspaceContextManaging

        private(set) var operationInProgress: UUID?
        private(set) var error: SettingsContextStoreError?

        private(set) var contextBeingEdited: WorkspaceContext?
        var isCreatingOrEditing = false

        init(contextManager: any WorkspaceContextManaging) {
            self.contextManager = contextManager
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

        func runContext(_ context: WorkspaceContext) async {
            guard operationInProgress == nil else { return }

            operationInProgress = context.id
            defer { operationInProgress = nil }

            do {
                try await contextManager.switchContext(id: context.id)
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
                error = nil
            } catch let error as SettingsContextStoreError {
                self.error = error
            } catch {
                self.error = .unknown
            }
        }
    }
}
