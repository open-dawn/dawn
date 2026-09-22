import Foundation

import PaEventKit

extension ContextCreatorView {
    @Observable
    final class ViewModel: BaseViewModel {
        private(set) var error: ViewModelError?
        private(set) var errorMessage: String?
        private(set) var isLoading: Bool
        var context: WorkspaceContext

        init() {
            self.error = nil
            self.errorMessage = nil
            self.isLoading = true
            defer { self.isLoading = false }

            self.context = WorkspaceContext(name: "", symbol: "")
        }

        public func addNewDefaultApp() {
            context.applications.append(
                WorkspaceApplication(
                    bundleIdentifier: "",
                    displayName: ""
                )
            )
        }

        public func removeApp(_ id: UUID) {
            if let index = context.applications.firstIndex(where: { $0.id == id }) {
                context.applications.remove(at: index)
                return
            }

            let invalidAppAttempError = ViewModelError.invalidAccess
            self.error = invalidAppAttempError
            self.errorMessage = invalidAppAttempError.errorDescription
        }

        public func saveContext() {
            // Pending: persist the created context.
        }
    }
}
