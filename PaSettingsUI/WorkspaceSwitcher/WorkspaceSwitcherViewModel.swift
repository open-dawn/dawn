import Foundation

extension WorkspaceSwitcherView {
    @Observable
    class ViewModel: BaseViewModel {
        private(set) var contexts: [Context]
        private(set) var contextActive: Context?

        private(set) var isCreatingOrEditing: Bool

        private(set) var error: NSError?
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
                self.error = error as NSError
                self.errorMessage = error.localizedDescription
            }
        }

        // MARK: - User Interactions
        public func runContext(_ context: Context) {
            // Pending: run the selected context.
            print("Calling runContext()")
        }

        public func editContext(_ context: Context) {
            // Pending: edit the selected context.
            print("Calling editContext()")
        }

        public func deleteContext(_ context: Context) {
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
        func fetchContexts() throws {
            self.contexts = Context.samples()
            self.contextActive = self.contexts[Int.random(in: 0..<contexts.count)]
            // Pending: load contexts from a repository.
        }
    }
}
