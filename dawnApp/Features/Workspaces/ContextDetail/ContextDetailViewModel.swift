import Foundation
import libdawn

@Observable
@MainActor
final class ContextDetailViewModel {
    private let contextManager: any WorkspaceContextManaging
    private let saveDebounce: Duration

    private(set) var operationInProgress: UUID?
    // swiftlint:disable:next todo
    // FIXME: Active context stays in this view model. dawnAgent records it on
    // WorkspaceRuntime.lastRequestedContextID for the in-process menu bar and
    // does not publish it, so another frontend only knows about activations it started.
    private(set) var activeContextID: UUID?
    private(set) var error: SettingsContextStoreError?
    private(set) var contextBeingEdited: WorkspaceContext?
    private(set) var draft: WorkspaceContext?
    private(set) var pendingSave: Task<Void, Never>?
    var isCreatingOrEditing: Bool

    private var committed: WorkspaceContext?
    private var latestSnapshot: WorkspaceContext?
    private var saveInFlight = false
    private var saveAgain = false

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
        guard let activeContextID else {
            return
        }

        let stillExists = contexts.contains { $0.id == activeContextID }
        if !stillExists {
            self.activeContextID = nil
        }
    }

    func runContext(_ context: WorkspaceContext) async {
        guard operationInProgress == nil else { return }

        operationInProgress = context.id
        defer { operationInProgress = nil }

        // PIN-145 Fixs it in future
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
        guard operationInProgress == nil else { return false }

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

    func adopt(_ snapshot: WorkspaceContext) {
        latestSnapshot = snapshot

        guard var current = draft, current.id == snapshot.id else {
            pendingSave?.cancel()
            pendingSave = nil
            saveAgain = false
            draft = snapshot
            committed = snapshot
            return
        }

        if current.name == committed?.name {
            current.name = snapshot.name
        }
        if current.symbol == committed?.symbol {
            current.symbol = snapshot.symbol
        }
        current.applications = snapshot.applications
        draft = current

        guard var committed, committed.id == snapshot.id else {
            return
        }

        committed.applications = snapshot.applications
        if current.name == snapshot.name {
            committed.name = snapshot.name
        }
        if current.symbol == snapshot.symbol {
            committed.symbol = snapshot.symbol
        }
        self.committed = committed
    }

    func setName(_ name: String) {
        guard var current = draft, current.name != name else {
            return
        }

        current.name = name
        draft = current
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
            return
        }

        let savingID = saving.id
        saveInFlight = true
        defer {
            saveInFlight = false
            let shouldRepeat = saveAgain
            saveAgain = false
            if shouldRepeat {
                scheduleSave(after: .zero)
            }
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
            if draftDiffers(from: saved) {
                saveAgain = true
            }
        case let .failure(error):
            self.error = error
            if let saving, draftDiffers(from: saving) {
                saveAgain = true
            }
        }
    }

    private func payloadToSave() -> WorkspaceContext? {
        guard var saving = draft else {
            return nil
        }

        if let latestSnapshot, latestSnapshot.id == saving.id {
            saving.applications = latestSnapshot.applications
        }

        guard let committed, committed.id == saving.id else {
            return saving
        }

        guard saving.name != committed.name || saving.symbol != committed.symbol else {
            return nil
        }

        return saving
    }

    private func draftDiffers(from saving: WorkspaceContext) -> Bool {
        guard let draft, draft.id == saving.id else {
            return false
        }

        return draft.name != saving.name || draft.symbol != saving.symbol
    }
}
