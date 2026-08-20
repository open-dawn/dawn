import Foundation

// TODO: PT-BR Commentary
// Talvez seja necessario mudar a logica para esses valores sempre
// existirem na memoria apos troca de tabs
extension WorkspaceSwitcherView {
    @Observable
    class ViewModel {
        private(set) var contexts: [Context]
        private(set) var contextActive: Context?
        private(set) var error: NSError?
        private(set) var loading: Bool

        init() {
            self.contexts = []
            self.error = nil
            self.loading = true
            defer { self.loading = false }

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
            print("Creating a new context()")
        }


        // MARK: - Fetch functions
        private func fetchContexts() throws {
            self.contexts = Context.samples()
            self.contextActive = self.contexts[Int.random(in: 0..<contexts.count)]
            // TODO: Implement reading values from repository
        }
    }
}
