import Foundation
import PaEventKit

private enum ContextCreatorMode: Equatable{
    case create
    case edit
}

extension ContextCreatorView {
    @Observable
    @MainActor
    final class ViewModel {
        private let contextSaver: any ContextSaving
        private let applicationSelector: any ApplicationSelecting

        private(set) var error: ViewModelError?
        private(set) var errorMessage: String?
        private(set) var saveError: PaSettingsContextStoreError?
        private(set) var applicationSelectionError: ApplicationSelectionError?
        private(set) var isLoading = false

        private let mode: ContextCreatorMode

        var isEditing: Bool {
            mode == .edit
        }

        var context: WorkspaceContext

        init(
            contextSaver: any ContextSaving,
            context: WorkspaceContext? = nil,
            applicationSelector: any ApplicationSelecting = SystemApplicationSelector()
        ) {
            self.contextSaver = contextSaver
            self.applicationSelector = applicationSelector

            if let context {
                self.context = context
                self.mode = .edit
            } else {
                self.context = WorkspaceContext(name: "", symbol: "")
                self.mode = .create
            }
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
                switch mode {
                case .create:
                    try await contextSaver.createContext(
                        name: context.name,
                        symbol: context.symbol,
                        applications: context.applications
                    )
                case .edit:
                    try await contextSaver.updateContext(context)
                }

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
