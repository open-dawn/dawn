import Foundation
import PaEventKit

extension WorkspaceSwitcherView {
    @Observable
    @MainActor
    class ViewModel {
        private let contextManager: any WorkspaceContextManaging

        private(set) var operationInProgress: UUID?
        private(set) var error: PaSettingsContextStoreError?

        var isCreatingOrEditing = false

        init(contextManager: any WorkspaceContextManaging) {
            self.contextManager = contextManager
        }

        // MARK: - User Interactions
        func presentContextCreator() {
            isCreatingOrEditing = true
        }

        func dismissContextCreator() {
            isCreatingOrEditing = false
        }

        func dismissError() {
            error = nil
        }

        public func runContext(_ context: WorkspaceContext) async {
            guard operationInProgress == nil else { return }

            operationInProgress = context.id
            defer { operationInProgress = nil }

            do {
                try await contextManager.switchContext(id: context.id)
                error = nil
            } catch let error as PaSettingsContextStoreError {
                self.error = error
            } catch {
                self.error = .unknown
            }
        }

        public func deleteContext(_ context: WorkspaceContext) async {
            guard operationInProgress == nil else { return }

            operationInProgress = context.id
            defer { operationInProgress = nil }

            do {
                try await contextManager.deleteContext(id: context.id)
                error = nil
            } catch let error as PaSettingsContextStoreError {
                self.error = error
            } catch {
                self.error = .unknown
            }
        }
    }
}
