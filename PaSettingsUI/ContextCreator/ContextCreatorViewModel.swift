import Foundation
import PaEventKit

extension ContextCreatorView {
    @Observable
    @MainActor
    final class ViewModel {
        private let contextCreator: any ContextCreating
        private let applicationSelector: any ApplicationSelecting

        private(set) var error: ViewModelError?
        private(set) var errorMessage: String?
        private(set) var saveError: PaSettingsContextStoreError?
        private(set) var applicationSelectionError: ApplicationSelectionError?
        private(set) var isLoading = false

        var context: WorkspaceContext

        init(
            contextCreator: any ContextCreating,
            applicationSelector: any ApplicationSelecting = SystemApplicationSelector()
        ) {
            self.contextCreator = contextCreator
            self.applicationSelector = applicationSelector
            self.context = WorkspaceContext(name: "", symbol: "")
        }

        func addApplication() async {
            guard !isLoading else {
                return
            }

            isLoading = true
            applicationSelectionError = nil
            defer { isLoading = false }

            do {
                guard let application = try await applicationSelector.selectApplication() else {
                    return
                }

                context.applications.append(application)
            } catch let error as ApplicationSelectionError {
                applicationSelectionError = error
            } catch {
                applicationSelectionError = .unknown
            }
        }

        func dismissApplicationSelectionError() {
            applicationSelectionError = nil
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

        @discardableResult
        public func saveContext() async -> Bool {
            guard !isLoading else {
                return false
            }

            isLoading = true
            defer { isLoading = false }

            do {
                try await contextCreator.createContext(
                    name: context.name,
                    symbol: context.symbol,
                    applications: context.applications
                )

                saveError = nil
                return true
            } catch let error as PaSettingsContextStoreError {
                saveError = error
                return false
            } catch {
                saveError = .unknown
                return false
            }
        }

        func dismissSaveError() {
            saveError = nil
        }
    }
}
