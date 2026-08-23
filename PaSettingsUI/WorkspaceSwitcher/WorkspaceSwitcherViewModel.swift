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

            try! self.fetchContexts()
        }

        // MARK: - User Interactions
        public func runContext(_ context: Context) {
            // TODO: Implement the function
            print("Calling runContext()")
        }

        public func editContext(_ context: Context) {
            // TODO: Implement the function
            print("Calling editContext()")
        }

        public func deleteContext(_ context: Context) {
            // TODO: Implement the function
            print("Calling deleteContext()")
        }

        public func createContext() {
            // TODO: Implement the function
            self.isCreatingOrEditing = true
        }

        public func cancelCreateContext() {
            self.isCreatingOrEditing = false
        }


        // MARK: - Fetch functions
        func fetchContexts() throws {
            self.contexts = Context.samples()
            self.contextActive = self.contexts[Int.random(in: 0..<contexts.count)]
            // TODO: Implement reading values from repository
        }
    }
}
