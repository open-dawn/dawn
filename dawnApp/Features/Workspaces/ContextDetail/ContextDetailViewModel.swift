import Foundation
import libdawn

@Observable
@MainActor
final class ContextDetailViewModel {
    private let contextManager: any WorkspaceContextManaging
    private let saveDebounce: Duration

    private(set) var operationInProgress: UUID?
    private(set) var activeContextID: UUID?
    private(set) var error: SettingsContextStoreError?
    var applicationImportError: ApplicationSelectionError?
    private(set) var contextBeingEdited: WorkspaceContext?
    private(set) var draft: WorkspaceContext?
    private(set) var pendingSave: Task<Void, Never>?
    var isCreatingOrEditing: Bool

    private var committed: WorkspaceContext?
    private var saveInFlight = false
    private var saveAgain = false
    private var isChangingArchival = false
    private var saveIdleWaiters: [CheckedContinuation<Void, Never>] = []

    init(
        contextManager: any WorkspaceContextManaging,
        saveDebounce: Duration = .milliseconds(300)
    ) {
        self.contextManager = contextManager
        self.saveDebounce = saveDebounce
        isCreatingOrEditing = false
    }

    func presentContextCreator() {
        contextBeingEdited = nil
        isCreatingOrEditing = true
    }

    func presentContextEditor(_ context: WorkspaceContext) {
        contextBeingEdited = context
        isCreatingOrEditing = true
    }

    func dismissContextCreator() {
        isCreatingOrEditing = false
        contextBeingEdited = nil
    }

    func dismissError() {
        error = nil
    }

    func reconcileActiveContext(with contexts: [WorkspaceContext]) {
        if let activeContextID,
           !contexts.contains(where: { $0.id == activeContextID }) {
            self.activeContextID = nil
        }
    }

    func synchronizeActiveContext(_ contextID: UUID?) { activeContextID = contextID }

    func runContext(_ context: WorkspaceContext) async {
        guard operationInProgress == nil, !isChangingArchival else { return }

        operationInProgress = context.id
        defer { operationInProgress = nil }

        await flushEdits(for: context.id)
        guard draft?.id != context.id || payloadToSave() == nil else {
            return
        }

        do {
            try await contextManager.switchContext(id: context.id)
            activeContextID = context.id
            error = nil
        } catch let error as SettingsContextStoreError {
            self.error = error
        } catch {
            self.error = .unknown
        }
    }

    @discardableResult
    func deleteContext(_ context: WorkspaceContext) async -> Bool {
        guard operationInProgress == nil, !isChangingArchival else { return false }

        operationInProgress = context.id
        defer { operationInProgress = nil }

        do {
            try await contextManager.deleteContext(id: context.id)
            if activeContextID == context.id {
                activeContextID = nil
            }
            error = nil
            return true
        } catch let error as SettingsContextStoreError {
            self.error = error
            return false
        } catch {
            self.error = .unknown
            return false
        }
    }

    @discardableResult
    func archiveContext(_ context: WorkspaceContext) async -> Bool {
        await changeArchival(of: context, archived: true)
    }

    @discardableResult
    func unarchiveContext(_ context: WorkspaceContext) async -> Bool {
        await changeArchival(of: context, archived: false)
    }

    func stopContext(_ context: WorkspaceContext) async {
        guard operationInProgress == nil, !isChangingArchival else { return }

        operationInProgress = context.id
        defer { operationInProgress = nil }

        await flushEdits(for: context.id)
        guard draft?.id != context.id || payloadToSave() == nil else {
            return
        }

        do {
            try await contextManager.stopContext(id: context.id)
            activeContextID = nil
            error = nil
        } catch let error as SettingsContextStoreError {
            self.error = error
        } catch {
            self.error = .unknown
        }
    }

    private func changeArchival(of context: WorkspaceContext, archived: Bool) async -> Bool {
        guard operationInProgress == nil, !isChangingArchival else { return false }

        // Archival must not use operationInProgress. The agent publishes the
        // updated list before it acknowledges the ask, so the row moves into
        // the visible section while that id is still busy and the sidebar
        // paints a ProgressView on a context that is already restored.
        isChangingArchival = true
        defer { isChangingArchival = false }

        do {
            if archived {
                try await contextManager.archiveContext(id: context.id)
                if activeContextID == context.id {
                    activeContextID = nil
                }
            } else {
                try await contextManager.unarchiveContext(id: context.id)
            }
            error = nil
            return true
        } catch let error as SettingsContextStoreError {
            self.error = error
            return false
        } catch {
            self.error = .unknown
            return false
        }
    }
}

extension ContextDetailViewModel {
    func adopt(_ snapshot: WorkspaceContext) {
        guard var current = draft, current.id == snapshot.id else {
            pendingSave?.cancel()
            pendingSave = nil
            saveAgain = false
            draft = snapshot
            committed = snapshot
            clearEmptyContextNameError()
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
        if !isBlankContextName(name) { clearEmptyContextNameError() }
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
            try await contextManager.updateContext(saving)
            finishSave(.success(saving), savingID: savingID)
        } catch let error as SettingsContextStoreError {
            finishSave(.failure(error), savingID: savingID, attempted: saving)
        } catch {
            finishSave(.failure(.unknown), savingID: savingID, attempted: saving)
        }
    }

    private func finishSave(
        _ result: Result<WorkspaceContext, SettingsContextStoreError>,
        savingID: UUID,
        attempted saving: WorkspaceContext? = nil
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

    private func resolvedSaveError(_ error: SettingsContextStoreError) -> SettingsContextStoreError? {
        if error.isEmptyContextName, !isBlankContextName(draft?.name ?? "") {
            return nil
        }

        return error
    }

    private func clearEmptyContextNameError() {
        if error?.isEmptyContextName == true { error = nil }
    }

    private func isBlankContextName(_ name: String) -> Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func normalizedTerminalCommand(_ command: String) -> String? {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func payloadToSave() -> WorkspaceContext? {
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

    private func flushEdits(for contextID: UUID) async {
        guard draft?.id == contextID else {
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
