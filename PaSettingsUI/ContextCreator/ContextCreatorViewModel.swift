import Foundation

extension ContextCreatorView {
    @Observable
    final class ViewModel: BaseViewModel {
        private(set) var error: NSError?
        private(set) var errorMessage: String?
        private(set) var isLoading: Bool 
        var context: Context

        init() {
            self.error = nil
            self.errorMessage = nil
            self.isLoading = true
            defer { self.isLoading = false }

            self.context = Context()
        }

        public func addNewDefaultApp() {
            self.context.apps.append(ContextApp())
        }

        public func removeApp(_ id: UUID) {
            if let index = context.apps.firstIndex(where: { $0.id == id }) {
                context.apps.remove(at: index)
            } 
        }

        public func saveContext() {
            // TODO: Implement
        } 
    }
}
