import Foundation
import libdawn

private enum WorkspaceCreatorMode: Equatable {
    case create
    case edit
}

@Observable
@MainActor
final class WorkspaceCreatorViewModel {
    private let workspaceSaver: any WorkspaceSaving
    private let applicationSelector: any ApplicationSelecting

    private(set) var error: ViewModelError?
    private(set) var errorMessage: String?
    private(set) var saveError: SettingsWorkspaceStoreError?
    private(set) var applicationSelectionError: ApplicationSelectionError?
    private(set) var isLoading = false

    private let mode: WorkspaceCreatorMode

    var isEditing: Bool {
        mode == .edit
    }

    var workspace: Workspace

    init(
        workspaceSaver: any WorkspaceSaving,
        workspace: Workspace? = nil,
        applicationSelector: any ApplicationSelecting = SystemApplicationSelector()
    ) {
        self.workspaceSaver = workspaceSaver
        self.applicationSelector = applicationSelector

        if let workspace {
            self.workspace = workspace
            self.mode = .edit
        } else {
            self.workspace = Workspace(name: "", symbol: "")
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

            workspace.applications.append(application)
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
        if let index = workspace.applications.firstIndex(where: { $0.id == id }) {
            workspace.applications.remove(at: index)
            return
        }

        let invalidAppAttempError = ViewModelError.invalidAccess
        self.error = invalidAppAttempError
        self.errorMessage = invalidAppAttempError.errorDescription
    }

    @discardableResult
    public func saveWorkspace() async -> Bool {
        guard !isLoading else {
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            switch mode {
            case .create:
                try await workspaceSaver.createWorkspace(
                    name: workspace.name,
                    symbol: workspace.symbol,
                    applications: workspace.applications,
                    transition: workspace.transition
                )
            case .edit:
                try await workspaceSaver.updateWorkspace(workspace)
            }

            saveError = nil
            return true
        } catch let error as SettingsWorkspaceStoreError {
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
