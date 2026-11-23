import Foundation
import libdawn

@Observable
@MainActor
final class WorkspaceDetailViewModel {
    private let workspaceCatalog: any AppWorkspaceManaging
    private let saveDebounce: Duration

    private(set) var operationInProgress: UUID?
    private(set) var activeWorkspaceID: UUID?
    private(set) var error: SettingsWorkspaceStoreError?
    var applicationImportError: ApplicationSelectionError?
    private(set) var workspaceBeingEdited: Workspace?
    private(set) var draft: Workspace?
    private(set) var pendingSave: Task<Void, Never>?
    var isCreatingOrEditing: Bool

    private var committed: Workspace?
    private var saveInFlight = false
    private var saveAgain = false
    private var isChangingArchival = false
    private var saveIdleWaiters: [CheckedContinuation<Void, Never>] = []

    init(
        workspaceCatalog: any AppWorkspaceManaging,
        saveDebounce: Duration = .milliseconds(300)
    ) {
        self.workspaceCatalog = workspaceCatalog
        self.saveDebounce = saveDebounce
        isCreatingOrEditing = false
    }

    func presentWorkspaceCreator() {
        workspaceBeingEdited = nil
        isCreatingOrEditing = true
    }

    func presentWorkspaceEditor(_ workspace: Workspace) {
        workspaceBeingEdited = workspace
        isCreatingOrEditing = true
    }

    func dismissWorkspaceCreator() {
        isCreatingOrEditing = false
        workspaceBeingEdited = nil
    }

    func dismissError() {
        error = nil
    }

    func reconcileActiveWorkspace(with workspaces: [Workspace]) {
        if let activeWorkspaceID,
           !workspaces.contains(where: { $0.id == activeWorkspaceID }) {
            self.activeWorkspaceID = nil
        }
    }

    func synchronizeActiveWorkspace(_ workspaceID: UUID?) { activeWorkspaceID = workspaceID }

    func runWorkspace(_ workspace: Workspace) async {
        guard operationInProgress == nil, !isChangingArchival else { return }

        operationInProgress = workspace.id
        defer { operationInProgress = nil }

        await flushEdits(for: workspace.id)
        guard draft?.id != workspace.id || payloadToSave() == nil else {
            return
        }

        do {
            try await workspaceCatalog.switchWorkspace(id: workspace.id)
            activeWorkspaceID = workspace.id
            error = nil
        } catch let error as SettingsWorkspaceStoreError {
            self.error = error
        } catch {
            self.error = .unknown
        }
    }

    @discardableResult
    func deleteWorkspace(_ workspace: Workspace) async -> Bool {
        guard operationInProgress == nil, !isChangingArchival else { return false }

        operationInProgress = workspace.id
        defer { operationInProgress = nil }

        do {
            try await workspaceCatalog.deleteWorkspace(id: workspace.id)
            if activeWorkspaceID == workspace.id {
                activeWorkspaceID = nil
            }
            error = nil
            return true
        } catch let error as SettingsWorkspaceStoreError {
            self.error = error
            return false
        } catch {
            self.error = .unknown
            return false
        }
    }

    @discardableResult
    func archiveWorkspace(_ workspace: Workspace) async -> Bool {
        await changeArchival(of: workspace, archived: true)
    }

    @discardableResult
    func unarchiveWorkspace(_ workspace: Workspace) async -> Bool {
        await changeArchival(of: workspace, archived: false)
    }

    func stopWorkspace(_ workspace: Workspace) async {
        guard operationInProgress == nil, !isChangingArchival else { return }

        operationInProgress = workspace.id
        defer { operationInProgress = nil }

        await flushEdits(for: workspace.id)
        guard draft?.id != workspace.id || payloadToSave() == nil else {
            return
        }

        do {
            try await workspaceCatalog.stopWorkspace(id: workspace.id)
            activeWorkspaceID = nil
            error = nil
        } catch let error as SettingsWorkspaceStoreError {
            self.error = error
        } catch {
            self.error = .unknown
        }
    }

    private func changeArchival(of workspace: Workspace, archived: Bool) async -> Bool {
        guard operationInProgress == nil, !isChangingArchival else { return false }

        // Archival must not use operationInProgress. The agent publishes the
        // updated list before it acknowledges the ask, so the row moves into
        // the visible section while that id is still busy and the sidebar
        // paints a ProgressView on a workspace that is already restored.
        isChangingArchival = true
        defer { isChangingArchival = false }

        do {
            if archived {
                try await workspaceCatalog.archiveWorkspace(id: workspace.id)
                if activeWorkspaceID == workspace.id {
                    activeWorkspaceID = nil
                }
            } else {
                try await workspaceCatalog.unarchiveWorkspace(id: workspace.id)
            }
            error = nil
            return true
        } catch let error as SettingsWorkspaceStoreError {
            self.error = error
            return false
        } catch {
            self.error = .unknown
            return false
        }
    }
}

extension WorkspaceDetailViewModel {
    func adopt(_ snapshot: Workspace) {
        guard var current = draft, current.id == snapshot.id else {
            pendingSave?.cancel()
            pendingSave = nil
            saveAgain = false
            draft = snapshot
            committed = snapshot
            clearEmptyWorkspaceNameError()
            return
        }

        current.mergeCleanFields(from: snapshot, committed: committed)
        current.isArchived = snapshot.isArchived
        draft = current

        guard var committed, committed.id == snapshot.id else {
            return
        }

        committed.isArchived = snapshot.isArchived
        committed.alignCleanFields(with: current, snapshot: snapshot)
        self.committed = committed
    }

    func setName(_ name: String) {
        guard var current = draft, current.name != name else {
            return
        }

        current.name = name
        draft = current
        if !isBlankWorkspaceName(name) { clearEmptyWorkspaceNameError() }
        scheduleSave(after: saveDebounce)
    }

    func setSymbol(_ symbol: String) {
        guard var current = draft, current.symbol != symbol else {
            return
        }

        current.symbol = symbol
        draft = current
        scheduleSave(after: .zero)
    }

    func setActivationPolicy(_ policy: WorkspaceActivationPolicy) {
        guard var current = draft, current.transition.activationPolicy != policy else {
            return
        }

        current.transition.activationPolicy = policy
        draft = current
        scheduleSave(after: .zero)
    }

    func setTerminalCommand(_ command: String) {
        guard var current = draft else {
            return
        }

        let normalized = normalizedTerminalCommand(command)
        guard current.transition.terminalCommand != normalized else {
            return
        }

        current.transition.terminalCommand = normalized
        draft = current
        scheduleSave(after: saveDebounce)
    }

    func setApplications(_ applications: [WorkspaceApplication]) {
        guard var current = draft, current.applications != applications else {
            return
        }

        current.applications = applications
        draft = current
        scheduleSave(after: .zero)
    }

    private func scheduleSave(after debounce: Duration) {
        guard payloadToSave() != nil else {
            pendingSave?.cancel()
            pendingSave = nil
            return
        }

        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            if debounce > .zero {
                try? await Task.sleep(for: debounce)
            }
            guard !Task.isCancelled, let self else {
                return
            }
            await self.commit()
        }
    }

    private func commit() async {
        if saveInFlight {
            saveAgain = true
            return
        }

        guard let saving = payloadToSave() else {
            saveAgain = false
            return
        }

        let savingID = saving.id
        saveAgain = false
        saveInFlight = true
        defer {
            saveInFlight = false
            let shouldRepeat = saveAgain
            saveAgain = false
            let waiters = saveIdleWaiters
            saveIdleWaiters.removeAll()
            if shouldRepeat, waiters.isEmpty {
                scheduleSave(after: .zero)
            } else if shouldRepeat {
                saveAgain = true
            }
            waiters.forEach { $0.resume() }
        }

        do {
            try await workspaceCatalog.updateWorkspace(saving)
            finishSave(.success(saving), savingID: savingID)
        } catch let error as SettingsWorkspaceStoreError {
            finishSave(.failure(error), savingID: savingID, attempted: saving)
        } catch {
            finishSave(.failure(.unknown), savingID: savingID, attempted: saving)
        }
    }

    private func finishSave(
        _ result: Result<Workspace, SettingsWorkspaceStoreError>,
        savingID: UUID,
        attempted saving: Workspace? = nil
    ) {
        guard draft?.id == savingID else {
            return
        }

        switch result {
        case let .success(saved):
            committed = saved
            error = nil
            if draft?.editableContentDiffers(from: saved) == true {
                saveAgain = true
            }

        case let .failure(error):
            self.error = resolvedSaveError(error)
            if let saving,
               draft?.editableContentDiffers(from: saving) == true {
                saveAgain = true
            }
        }
    }

    private func resolvedSaveError(_ error: SettingsWorkspaceStoreError) -> SettingsWorkspaceStoreError? {
        if error.isEmptyWorkspaceName, !isBlankWorkspaceName(draft?.name ?? "") {
            return nil
        }

        return error
    }

    private func clearEmptyWorkspaceNameError() {
        if error?.isEmptyWorkspaceName == true { error = nil }
    }

    private func isBlankWorkspaceName(_ name: String) -> Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func normalizedTerminalCommand(_ command: String) -> String? {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func payloadToSave() -> Workspace? {
        guard let saving = draft else {
            return nil
        }

        guard let committed, committed.id == saving.id else {
            return saving
        }

        guard saving.editableContentDiffers(from: committed) else {
            return nil
        }

        return saving
    }

    private func flushEdits(for workspaceID: UUID) async {
        guard draft?.id == workspaceID else {
            return
        }

        if saveInFlight {
            saveAgain = true
            await withCheckedContinuation { continuation in
                saveIdleWaiters.append(continuation)
            }
        }

        pendingSave?.cancel()
        pendingSave = nil
        await commit()
    }
}
