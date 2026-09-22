import Foundation

import PaEventKit

extension WorkspaceSwitcherView {
    @Observable
    class ViewModel: BaseViewModel {
        private(set) var contexts: [WorkspaceContext]
        private(set) var contextActive: WorkspaceContext?

        private(set) var isCreatingOrEditing: Bool

        private(set) var error: ViewModelError?
        private(set) var errorMessage: String?
        private(set) var isLoading: Bool

        init() {
            self.contexts = []
            self.error = nil
            self.isLoading = true
            defer { self.isLoading = false }

            self.isCreatingOrEditing = false

            do {
                try self.fetchContexts()
            } catch {
                self.error = error
                self.errorMessage = error.errorDescription
            }
        }

        // MARK: - User Interactions
        public func runContext(_ context: WorkspaceContext) {
            // Pending: run the selected context.
            print("Calling runContext()")
        }

        public func editContext(_ context: WorkspaceContext) {
            // Pending: edit the selected context.
            print("Calling editContext()")
        }

        public func deleteContext(_ context: WorkspaceContext) {
            // Pending: delete the selected context.
            print("Calling deleteContext()")
        }

        public func createContext() {
            // Pending: create a new context.
            self.isCreatingOrEditing = true
        }

        public func cancelCreateContext() {
            self.isCreatingOrEditing = false
        }

        // MARK: - Fetch functions
        func fetchContexts() throws(ViewModelError) {
            contexts = []
            contextActive = nil
            // Pending: load contexts from a repository.
        }
    }
}
