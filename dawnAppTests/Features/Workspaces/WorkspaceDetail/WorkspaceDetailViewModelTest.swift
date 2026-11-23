@testable import dawnApp
import Foundation
import libdawn
import Testing

@MainActor
@Suite("WorkspaceDetail ViewModel")
struct WorkspaceDetailViewModelTests {
    @Test("Starts with no active operation, error, or presented creator")
    func initialState() {
        let workspaceCatalog = WorkspaceCatalogSpy()
        let viewModel = WorkspaceDetailViewModel(workspaceCatalog: workspaceCatalog)

        #expect(viewModel.operationInProgress == nil)
        #expect(viewModel.activeWorkspaceID == nil)
        #expect(viewModel.error == nil)
        #expect(viewModel.isCreatingOrEditing == false)
        #expect(viewModel.workspaceBeingEdited == nil)
    }

    @Test("Synchronizes activity changes received from the agent")
    func synchronizesAgentActivity() {
        let workspaceID = UUID()
        let viewModel = WorkspaceDetailViewModel(
            workspaceCatalog: WorkspaceCatalogSpy()
        )

        viewModel.synchronizeActiveWorkspace(workspaceID)
        #expect(viewModel.activeWorkspaceID == workspaceID)

        viewModel.synchronizeActiveWorkspace(nil)
        #expect(viewModel.activeWorkspaceID == nil)
    }

    @Test("Presents and dismisses the workspace creator")
    func workspaceCreatorPresentation() throws {
        let workspaceCatalog = WorkspaceCatalogSpy()
        let viewModel = WorkspaceDetailViewModel(workspaceCatalog: workspaceCatalog)

        viewModel.presentWorkspaceCreator()
        try #require(viewModel.isCreatingOrEditing == true)

        viewModel.dismissWorkspaceCreator()
        #expect(viewModel.isCreatingOrEditing == false)
    }

    @Test("Run delegates the selected workspace identifier")
    func runWorkspace() async {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )

        let workspaceCatalog = WorkspaceCatalogSpy()
        let viewModel = WorkspaceDetailViewModel(workspaceCatalog: workspaceCatalog)

        var observedOperationID: UUID?
        workspaceCatalog.onSwitch = { observedOperationID = viewModel.operationInProgress }

        await viewModel.runWorkspace(workspace)

        #expect(workspaceCatalog.switchedWorkspaceIDs == [workspace.id])
        #expect(observedOperationID == workspace.id)
        #expect(viewModel.operationInProgress == nil)
        #expect(viewModel.activeWorkspaceID == workspace.id)
        #expect(viewModel.error == nil)
    }

    @Test("Stop delegates the active workspace identifier and clears active state")
    func stopWorkspace() async {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )

        let workspaceCatalog = WorkspaceCatalogSpy()
        let viewModel = WorkspaceDetailViewModel(workspaceCatalog: workspaceCatalog)

        await viewModel.runWorkspace(workspace)

        var observedOperationID: UUID?
        workspaceCatalog.onStop = { observedOperationID = viewModel.operationInProgress }

        await viewModel.stopWorkspace(workspace)

        #expect(workspaceCatalog.stoppedWorkspaceIDs == [workspace.id])
        #expect(observedOperationID == workspace.id)
        #expect(viewModel.activeWorkspaceID == nil)
        #expect(viewModel.operationInProgress == nil)
        #expect(viewModel.error == nil)
    }

    @Test("A failed stop preserves active state and exposes the error")
    func stopWorkspaceFailure() async {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )

        let workspaceCatalog = WorkspaceCatalogSpy()
        let viewModel = WorkspaceDetailViewModel(workspaceCatalog: workspaceCatalog)

        await viewModel.runWorkspace(workspace)
        workspaceCatalog.error = SettingsWorkspaceStoreError.notConnected

        await viewModel.stopWorkspace(workspace)

        #expect(workspaceCatalog.stoppedWorkspaceIDs == [workspace.id])
        #expect(viewModel.activeWorkspaceID == workspace.id)
        #expect(viewModel.operationInProgress == nil)
        #expect(viewModel.error == .notConnected)
    }

    @Test("Delete delegates the selected workspace identifier")
    func deleteWorkspace() async {
        let workspace = Workspace(
            name: "Personal",
            symbol: "person"
        )

        let workspaceCatalog = WorkspaceCatalogSpy()
        let viewModel = WorkspaceDetailViewModel(workspaceCatalog: workspaceCatalog)

        await viewModel.deleteWorkspace(workspace)

        #expect(workspaceCatalog.deletedWorkspaceIDs == [workspace.id])
        #expect(viewModel.operationInProgress == nil)
        #expect(viewModel.error == nil)
    }

    @Test("A workspace-manager error is exposed and operation state is cleared")
    func workspaceCatalogError() async {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )

        let workspaceCatalog = WorkspaceCatalogSpy()
        workspaceCatalog.error = SettingsWorkspaceStoreError.notConnected

        let viewModel = WorkspaceDetailViewModel(workspaceCatalog: workspaceCatalog)

        await viewModel.runWorkspace(workspace)

        #expect(workspaceCatalog.switchedWorkspaceIDs == [workspace.id])
        #expect(viewModel.error == .notConnected)
        #expect(viewModel.operationInProgress == nil)
        #expect(viewModel.activeWorkspaceID == nil)
    }

    @Test("A successful operation clears the previous error")
    func successfulOperationClearsError() async {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )

        let workspaceCatalog = WorkspaceCatalogSpy()
        workspaceCatalog.error = SettingsWorkspaceStoreError.timeout

        let viewModel = WorkspaceDetailViewModel(workspaceCatalog: workspaceCatalog)

        await viewModel.runWorkspace(workspace)
        #expect(viewModel.error == .timeout)

        workspaceCatalog.error = nil
        await viewModel.runWorkspace(workspace)

        #expect(viewModel.error == nil)
        #expect(viewModel.operationInProgress == nil)
    }

    @Test("An unknown error maps to unknown")
    func unknownError() async {
        let workspace = Workspace(
            name: "Personal",
            symbol: "person"
        )

        let workspaceCatalog = WorkspaceCatalogSpy()
        workspaceCatalog.error = TestError.expected

        let viewModel = WorkspaceDetailViewModel(workspaceCatalog: workspaceCatalog)

        await viewModel.deleteWorkspace(workspace)

        #expect(viewModel.error == .unknown)
        #expect(viewModel.operationInProgress == nil)
    }

    @Test("Presents the editor with the selected workspace")
    func workspaceEditorPresentation() {
        let workspace = Workspace(
            name: "Personal",
            symbol: "person"
        )
        let viewModel = WorkspaceDetailViewModel(workspaceCatalog: WorkspaceCatalogSpy())

        viewModel.presentWorkspaceEditor(workspace)

        #expect(viewModel.isCreatingOrEditing == true)
        #expect(viewModel.workspaceBeingEdited == workspace)

        viewModel.dismissWorkspaceCreator()

        #expect(viewModel.isCreatingOrEditing == false)
        #expect(viewModel.workspaceBeingEdited == nil)
    }

    @Test("Presenting the creator clears the editing workspace")
    func creatorClearsEditingWorkspace() {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )
        let viewModel = WorkspaceDetailViewModel(workspaceCatalog: WorkspaceCatalogSpy())

        viewModel.presentWorkspaceEditor(workspace)
        viewModel.presentWorkspaceCreator()

        #expect(viewModel.isCreatingOrEditing == true)
        #expect(viewModel.workspaceBeingEdited == nil)
    }

    @Test("Dismiss error clears the operation error")
    func dismissErrorClearsOperationError() async {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )

        let workspaceCatalog = WorkspaceCatalogSpy()
        workspaceCatalog.error = SettingsWorkspaceStoreError.notConnected

        let viewModel = WorkspaceDetailViewModel(workspaceCatalog: workspaceCatalog)

        await viewModel.runWorkspace(workspace)
        #expect(viewModel.error == .notConnected)

        viewModel.dismissError()
        #expect(viewModel.error == nil)
    }

    @Test("Archiving the active workspace clears the active marker")
    func archiveClearsActiveWorkspace() async {
        let workspace = Workspace(name: "Work", symbol: "briefcase")
        let workspaceCatalog = WorkspaceCatalogSpy()
        let viewModel = WorkspaceDetailViewModel(workspaceCatalog: workspaceCatalog)

        await viewModel.runWorkspace(workspace)
        let archived = await viewModel.archiveWorkspace(workspace)

        #expect(archived)
        #expect(workspaceCatalog.archivedWorkspaceIDs == [workspace.id])
        #expect(viewModel.activeWorkspaceID == nil)
        #expect(viewModel.operationInProgress == nil)
        #expect(viewModel.error == nil)
    }

    @Test("Unarchiving delegates the workspace identifier")
    func unarchiveWorkspace() async {
        var workspace = Workspace(name: "Work", symbol: "briefcase")
        workspace.isArchived = true
        let workspaceCatalog = WorkspaceCatalogSpy()
        let viewModel = WorkspaceDetailViewModel(workspaceCatalog: workspaceCatalog)

        var operationDuringUnarchive: UUID?
        workspaceCatalog.onUnarchive = {
            operationDuringUnarchive = viewModel.operationInProgress
        }

        let restored = await viewModel.unarchiveWorkspace(workspace)

        #expect(restored)
        #expect(workspaceCatalog.unarchivedWorkspaceIDs == [workspace.id])
        #expect(operationDuringUnarchive == nil)
        #expect(viewModel.operationInProgress == nil)
        #expect(viewModel.error == nil)
    }

    @Test("A failed archive sets the error and leaves operation state clear")
    func archiveFailureSetsError() async {
        let workspace = Workspace(name: "Work", symbol: "briefcase")
        let workspaceCatalog = WorkspaceCatalogSpy()
        workspaceCatalog.error = SettingsWorkspaceStoreError.notConnected
        let viewModel = WorkspaceDetailViewModel(workspaceCatalog: workspaceCatalog)

        let archived = await viewModel.archiveWorkspace(workspace)

        #expect(!archived)
        #expect(workspaceCatalog.archivedWorkspaceIDs == [workspace.id])
        #expect(viewModel.error == .notConnected)
        #expect(viewModel.operationInProgress == nil)
    }

    @Test("Adopting a snapshot refreshes archival without dropping a dirty name")
    func adoptRefreshesArchival() async {
        let workspace = Workspace(name: "Work", symbol: "briefcase")
        let viewModel = WorkspaceDetailViewModel(
            workspaceCatalog: WorkspaceCatalogSpy(),
            saveDebounce: .zero
        )
        viewModel.adopt(workspace)
        viewModel.setName("Dirty")

        var archived = workspace
        archived.isArchived = true
        viewModel.adopt(archived)

        #expect(viewModel.draft?.name == "Dirty")
        #expect(viewModel.draft?.isArchived == true)

        await viewModel.pendingSave?.value
    }

    @Test("Deleting the active workspace clears the active marker")
    func deleteClearsActiveWorkspace() async {
        let workspace = Workspace(name: "Work", symbol: "briefcase")
        let viewModel = WorkspaceDetailViewModel(workspaceCatalog: WorkspaceCatalogSpy())

        await viewModel.runWorkspace(workspace)
        await viewModel.deleteWorkspace(workspace)

        #expect(viewModel.activeWorkspaceID == nil)
    }

    @Test("Reconciliation clears the active workspace when it is removed")
    func reconcileClearsMissingActiveWorkspace() async {
        let workspace = Workspace(name: "Work", symbol: "briefcase")
        let viewModel = WorkspaceDetailViewModel(workspaceCatalog: WorkspaceCatalogSpy())

        await viewModel.runWorkspace(workspace)
        viewModel.reconcileActiveWorkspace(with: [])

        #expect(viewModel.activeWorkspaceID == nil)
    }

    @Test("Reconciliation keeps the active workspace while it still exists")
    func reconcileKeepsExistingActiveWorkspace() async {
        let workspace = Workspace(name: "Work", symbol: "briefcase")
        let viewModel = WorkspaceDetailViewModel(workspaceCatalog: WorkspaceCatalogSpy())

        await viewModel.runWorkspace(workspace)
        viewModel.reconcileActiveWorkspace(with: [workspace])

        #expect(viewModel.activeWorkspaceID == workspace.id)
    }

    @Test("Adopting a snapshot updates an idle draft")
    func adoptUpdatesIdleDraft() {
        let workspace = Workspace(name: "Work", symbol: "briefcase")
        let viewModel = WorkspaceDetailViewModel(
            workspaceCatalog: WorkspaceCatalogSpy(),
            saveDebounce: .zero
        )
        viewModel.adopt(workspace)

        let refreshed = Workspace(
            id: workspace.id,
            name: "Workspace",
            symbol: "star",
            applications: [sampleApplication],
            transition: WorkspaceTransition(
                activationPolicy: .merge,
                terminalCommand: "echo hi"
            )
        )
        viewModel.adopt(refreshed)

        #expect(viewModel.draft == refreshed)
    }

    @Test("Adopting a snapshot keeps a dirty name and refreshes applications")
    func adoptKeepsDirtyName() async {
        let workspace = Workspace(name: "Work", symbol: "briefcase")
        let viewModel = WorkspaceDetailViewModel(
            workspaceCatalog: WorkspaceCatalogSpy(),
            saveDebounce: .zero
        )
        viewModel.adopt(workspace)
        viewModel.setName("Dirty")

        let refreshed = Workspace(
            id: workspace.id,
            name: "Remote",
            symbol: "star",
            applications: [sampleApplication]
        )
        viewModel.adopt(refreshed)

        #expect(viewModel.draft?.name == "Dirty")
        #expect(viewModel.draft?.symbol == "star")
        #expect(viewModel.draft?.applications == [sampleApplication])

        await viewModel.pendingSave?.value
    }

    @Test("Switching ids replaces the draft")
    func adoptSwitchesWorkspace() async {
        let first = Workspace(name: "Work", symbol: "briefcase")
        let second = Workspace(name: "Personal", symbol: "person")
        let workspaceCatalog = WorkspaceCatalogSpy()
        let viewModel = WorkspaceDetailViewModel(
            workspaceCatalog: workspaceCatalog,
            saveDebounce: .zero
        )

        viewModel.adopt(first)
        viewModel.setName("Dirty")
        let pendingSave = viewModel.pendingSave
        viewModel.adopt(second)
        await pendingSave?.value

        #expect(workspaceCatalog.updatedWorkspaces.isEmpty)
        #expect(viewModel.draft == second)
    }

    @Test("A debounced name change saves the final name and snapshot applications")
    func debouncedNameSaveUsesSnapshotApplications() async {
        let workspace = Workspace(name: "Work", symbol: "briefcase")
        let workspaceCatalog = WorkspaceCatalogSpy()
        let viewModel = WorkspaceDetailViewModel(
            workspaceCatalog: workspaceCatalog,
            saveDebounce: .zero
        )

        viewModel.adopt(workspace)
        viewModel.adopt(
            Workspace(
                id: workspace.id,
                name: workspace.name,
                symbol: workspace.symbol,
                applications: [sampleApplication]
            )
        )
        viewModel.setName("Worksp")
        viewModel.setName("Workspace")
        await viewModel.pendingSave?.value

        #expect(workspaceCatalog.updatedWorkspaces.count == 1)
        #expect(workspaceCatalog.updatedWorkspaces.first?.id == workspace.id)
        #expect(workspaceCatalog.updatedWorkspaces.first?.name == "Workspace")
        #expect(workspaceCatalog.updatedWorkspaces.first?.symbol == "briefcase")
        #expect(workspaceCatalog.updatedWorkspaces.first?.applications == [sampleApplication])
        #expect(viewModel.operationInProgress == nil)
    }

    @Test("An activation policy change saves immediately without dropping the terminal command")
    func activationPolicySaveKeepsTerminalCommand() async {
        let workspace = Workspace(name: "Work", symbol: "briefcase")
        let workspaceCatalog = WorkspaceCatalogSpy()
        let viewModel = WorkspaceDetailViewModel(
            workspaceCatalog: workspaceCatalog,
            saveDebounce: .zero
        )

        viewModel.adopt(workspace)
        viewModel.adopt(
            Workspace(
                id: workspace.id,
                name: workspace.name,
                symbol: workspace.symbol,
                applications: [sampleApplication],
                transition: WorkspaceTransition(
                    activationPolicy: .hide,
                    terminalCommand: "echo remote"
                )
            )
        )
        viewModel.setActivationPolicy(.close)
        await viewModel.pendingSave?.value

        let saved = workspaceCatalog.updatedWorkspaces.first
        #expect(saved?.transition.activationPolicy == .close)
        #expect(saved?.transition.terminalCommand == "echo remote")
        #expect(saved?.applications == [sampleApplication])
        #expect(saved?.name == "Work")
        #expect(viewModel.operationInProgress == nil)
    }

    @Test("Adopting a snapshot keeps a dirty activation policy and refreshes the terminal command")
    func adoptKeepsDirtyActivationPolicy() async {
        let workspace = Workspace(name: "Work", symbol: "briefcase")
        let viewModel = WorkspaceDetailViewModel(
            workspaceCatalog: WorkspaceCatalogSpy(),
            saveDebounce: .zero
        )
        viewModel.adopt(workspace)
        viewModel.setActivationPolicy(.merge)

        var remote = workspace
        remote.transition = WorkspaceTransition(
            activationPolicy: .close,
            terminalCommand: "echo remote"
        )
        viewModel.adopt(remote)

        #expect(viewModel.draft?.transition.activationPolicy == .merge)
        #expect(viewModel.draft?.transition.terminalCommand == "echo remote")

        await viewModel.pendingSave?.value
        #expect(viewModel.draft?.transition.activationPolicy == .merge)
    }

    @Test("An application edit saves that list and keeps the snapshot terminal command")
    func applicationEditSavesDraftList() async {
        let workspace = Workspace(name: "Work", symbol: "briefcase")
        let workspaceCatalog = WorkspaceCatalogSpy()
        let viewModel = WorkspaceDetailViewModel(
            workspaceCatalog: workspaceCatalog,
            saveDebounce: .zero
        )

        viewModel.adopt(workspace)
        viewModel.adopt(
            Workspace(
                id: workspace.id,
                name: workspace.name,
                symbol: workspace.symbol,
                applications: [sampleApplication],
                transition: WorkspaceTransition(
                    activationPolicy: .hide,
                    terminalCommand: "echo remote"
                )
            )
        )
        viewModel.setApplications([otherApplication])
        await viewModel.pendingSave?.value

        let saved = workspaceCatalog.updatedWorkspaces.first
        #expect(workspaceCatalog.updatedWorkspaces.count == 1)
        #expect(saved?.applications == [otherApplication])
        #expect(saved?.name == "Work")
        #expect(saved?.symbol == "briefcase")
        #expect(saved?.transition.activationPolicy == .hide)
        #expect(saved?.transition.terminalCommand == "echo remote")
        #expect(viewModel.operationInProgress == nil)
    }

    @Test("Adopting a snapshot keeps dirty applications and refreshes a clean name")
    func adoptKeepsDirtyApplications() async {
        let workspace = Workspace(name: "Work", symbol: "briefcase")
        let workspaceCatalog = WorkspaceCatalogSpy()
        let viewModel = WorkspaceDetailViewModel(
            workspaceCatalog: workspaceCatalog,
            saveDebounce: .zero
        )
        viewModel.adopt(workspace)
        viewModel.setApplications([otherApplication])

        let refreshed = Workspace(
            id: workspace.id,
            name: "Remote",
            symbol: "star",
            applications: [sampleApplication],
            transition: WorkspaceTransition(
                activationPolicy: .close,
                terminalCommand: "echo remote"
            )
        )
        viewModel.adopt(refreshed)

        #expect(viewModel.draft?.applications == [otherApplication])
        #expect(viewModel.draft?.name == "Remote")
        #expect(viewModel.draft?.symbol == "star")
        #expect(viewModel.draft?.transition.terminalCommand == "echo remote")

        await viewModel.pendingSave?.value
        let saved = workspaceCatalog.updatedWorkspaces.first
        #expect(workspaceCatalog.updatedWorkspaces.count == 1)
        #expect(saved?.applications == [otherApplication])
        #expect(saved?.name == "Remote")
        #expect(saved?.symbol == "star")
        #expect(saved?.transition.terminalCommand == "echo remote")
    }

    @Test("A later name edit keeps applications saved ahead of the snapshot")
    func nameEditKeepsApplicationsSavedAheadOfSnapshot() async {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase",
            applications: [sampleApplication]
        )
        let workspaceCatalog = WorkspaceCatalogSpy()
        let viewModel = WorkspaceDetailViewModel(
            workspaceCatalog: workspaceCatalog,
            saveDebounce: .zero
        )

        viewModel.adopt(workspace)
        viewModel.setApplications([otherApplication])
        await viewModel.pendingSave?.value
        viewModel.setName("Workspace")
        await viewModel.pendingSave?.value

        #expect(workspaceCatalog.updatedWorkspaces.map(\.applications) == [
            [otherApplication],
            [otherApplication]
        ])
        #expect(workspaceCatalog.updatedWorkspaces.last?.name == "Workspace")
    }

    @Test("Activate saves a pending application edit before switching")
    func runWorkspaceFlushesApplications() async {
        let workspace = Workspace(name: "Work", symbol: "briefcase")
        let workspaceCatalog = WorkspaceCatalogSpy()
        let viewModel = WorkspaceDetailViewModel(
            workspaceCatalog: workspaceCatalog,
            saveDebounce: .zero
        )

        viewModel.adopt(workspace)
        viewModel.setApplications([otherApplication])

        var savedBeforeSwitch = false
        workspaceCatalog.onSwitch = {
            savedBeforeSwitch = workspaceCatalog.updatedWorkspaces.last?.applications == [otherApplication]
        }

        await viewModel.runWorkspace(workspace)

        #expect(savedBeforeSwitch)
        #expect(workspaceCatalog.switchedWorkspaceIDs == [workspace.id])
        #expect(viewModel.activeWorkspaceID == workspace.id)
    }

    @Test("Dropping application bundles appends them and keeps the terminal command")
    func dropImportsApplications() async throws {
        let mail = try makeApplicationBundle(
            name: "Mail",
            bundleIdentifier: "com.example.mail",
            displayName: "Example Mail"
        )
        let notes = try makeApplicationBundle(
            name: "Notes",
            bundleIdentifier: "com.example.notes",
            displayName: "Example Notes"
        )
        defer {
            try? FileManager.default.removeItem(at: mail.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: notes.deletingLastPathComponent())
        }

        let workspace = Workspace(name: "Work", symbol: "briefcase")
        let workspaceCatalog = WorkspaceCatalogSpy()
        let viewModel = WorkspaceDetailViewModel(
            workspaceCatalog: workspaceCatalog,
            saveDebounce: .zero
        )
        viewModel.adopt(workspace)
        viewModel.adopt(
            Workspace(
                id: workspace.id,
                name: workspace.name,
                symbol: workspace.symbol,
                transition: WorkspaceTransition(
                    activationPolicy: .hide,
                    terminalCommand: "echo remote"
                )
            )
        )

        let accepted = viewModel.addApplications(at: [mail, notes])
        await viewModel.pendingSave?.value

        let saved = workspaceCatalog.updatedWorkspaces.first
        #expect(accepted)
        #expect(workspaceCatalog.updatedWorkspaces.count == 1)
        #expect(saved?.applications.map(\.bundleIdentifier) == [
            "com.example.mail",
            "com.example.notes"
        ])
        #expect(saved?.applications.map(\.displayName) == ["Example Mail", "Example Notes"])
        #expect(saved?.transition.terminalCommand == "echo remote")
        #expect(saved?.transition.activationPolicy == .hide)
        #expect(viewModel.applicationImportError == nil)
    }

    @Test("Dropping an application that is already listed does not save again")
    func dropSkipsDuplicateBundleIdentifier() async throws {
        let mail = try makeApplicationBundle(
            name: "Mail",
            bundleIdentifier: sampleApplication.bundleIdentifier,
            displayName: "Other Mail"
        )
        defer {
            try? FileManager.default.removeItem(at: mail.deletingLastPathComponent())
        }

        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase",
            applications: [sampleApplication]
        )
        let workspaceCatalog = WorkspaceCatalogSpy()
        let viewModel = WorkspaceDetailViewModel(
            workspaceCatalog: workspaceCatalog,
            saveDebounce: .zero
        )
        viewModel.adopt(workspace)

        let accepted = viewModel.addApplications(at: [mail])
        await viewModel.pendingSave?.value

        #expect(accepted)
        #expect(workspaceCatalog.updatedWorkspaces.isEmpty)
        #expect(viewModel.draft?.applications == [sampleApplication])
        #expect(viewModel.applicationImportError == nil)
    }

    @Test("A drop that mixes a file with an application adds the application and reports the file")
    func dropReportsInvalidItemAndKeepsValidApplication() async throws {
        let mail = try makeApplicationBundle(
            name: "Mail",
            bundleIdentifier: "com.example.mail",
            displayName: "Example Mail"
        )
        let document = mail.deletingLastPathComponent().appendingPathComponent("notes.txt")
        try Data("notes".utf8).write(to: document)
        defer {
            try? FileManager.default.removeItem(at: mail.deletingLastPathComponent())
        }

        let workspace = Workspace(name: "Work", symbol: "briefcase")
        let workspaceCatalog = WorkspaceCatalogSpy()
        let viewModel = WorkspaceDetailViewModel(
            workspaceCatalog: workspaceCatalog,
            saveDebounce: .zero
        )
        viewModel.adopt(workspace)

        let accepted = viewModel.addApplications(at: [document, mail])
        await viewModel.pendingSave?.value

        #expect(accepted)
        #expect(viewModel.applicationImportError == .invalidApplication)
        #expect(workspaceCatalog.updatedWorkspaces.first?.applications.map(\.bundleIdentifier) == [
            "com.example.mail"
        ])

        viewModel.dismissApplicationImportError()
        #expect(viewModel.applicationImportError == nil)
    }

    @Test("Removing an application saves the remaining list and the terminal command")
    func removeApplicationSavesRemainingList() async {
        let workspace = Workspace(name: "Work", symbol: "briefcase")
        let workspaceCatalog = WorkspaceCatalogSpy()
        let viewModel = WorkspaceDetailViewModel(
            workspaceCatalog: workspaceCatalog,
            saveDebounce: .zero
        )

        viewModel.adopt(workspace)
        viewModel.adopt(
            Workspace(
                id: workspace.id,
                name: workspace.name,
                symbol: workspace.symbol,
                applications: [sampleApplication, otherApplication],
                transition: WorkspaceTransition(
                    activationPolicy: .hide,
                    terminalCommand: "echo remote"
                )
            )
        )
        viewModel.removeApplication(id: sampleApplication.id)
        await viewModel.pendingSave?.value

        let saved = workspaceCatalog.updatedWorkspaces.first
        #expect(workspaceCatalog.updatedWorkspaces.count == 1)
        #expect(saved?.applications == [otherApplication])
        #expect(saved?.name == "Work")
        #expect(saved?.transition.activationPolicy == .hide)
        #expect(saved?.transition.terminalCommand == "echo remote")
    }

    @Test("A picker selection keeps existing rows, appends new ones, and drops the rest")
    func applyApplicationSelectionMergesByBundleIdentifier() async {
        let kept = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            createsNewApplicationInstance: true
        )
        let removed = WorkspaceApplication(
            bundleIdentifier: "com.apple.mail",
            displayName: "Mail"
        )
        let added = WorkspaceApplication(
            bundleIdentifier: "com.apple.Notes",
            displayName: "Notes"
        )
        let workspace = Workspace(name: "Work", symbol: "briefcase")
        let workspaceCatalog = WorkspaceCatalogSpy()
        let viewModel = WorkspaceDetailViewModel(
            workspaceCatalog: workspaceCatalog,
            saveDebounce: .zero
        )

        viewModel.adopt(workspace)
        viewModel.adopt(
            Workspace(
                id: workspace.id,
                name: workspace.name,
                symbol: workspace.symbol,
                applications: [kept, removed],
                transition: WorkspaceTransition(
                    activationPolicy: .hide,
                    terminalCommand: "echo remote"
                )
            )
        )
        viewModel.applyApplicationSelection([
            WorkspaceApplication(
                bundleIdentifier: kept.bundleIdentifier,
                displayName: "Renamed Safari",
                createsNewApplicationInstance: false
            ),
            added
        ])
        await viewModel.pendingSave?.value

        let saved = workspaceCatalog.updatedWorkspaces.first
        #expect(workspaceCatalog.updatedWorkspaces.count == 1)
        #expect(saved?.applications == [kept, added])
        #expect(saved?.applications.first?.id == kept.id)
        #expect(saved?.applications.first?.createsNewApplicationInstance == true)
        #expect(saved?.transition.terminalCommand == "echo remote")
        #expect(saved?.transition.activationPolicy == .hide)
    }

    @Test("A picker selection that matches the current list does not save")
    func applyApplicationSelectionSkipsUnchangedList() async {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase",
            applications: [sampleApplication, otherApplication]
        )
        let workspaceCatalog = WorkspaceCatalogSpy()
        let viewModel = WorkspaceDetailViewModel(
            workspaceCatalog: workspaceCatalog,
            saveDebounce: .zero
        )
        viewModel.adopt(workspace)

        viewModel.applyApplicationSelection([
            WorkspaceApplication(
                bundleIdentifier: otherApplication.bundleIdentifier,
                displayName: otherApplication.displayName
            ),
            WorkspaceApplication(
                bundleIdentifier: sampleApplication.bundleIdentifier,
                displayName: "Renamed Safari"
            )
        ])
        await viewModel.pendingSave?.value

        #expect(workspaceCatalog.updatedWorkspaces.isEmpty)
        #expect(viewModel.draft?.applications == [sampleApplication, otherApplication])
    }

    @Test("Activate saves a pending activation policy before switching")
    func runWorkspaceFlushesActivationPolicy() async {
        let workspace = Workspace(name: "Work", symbol: "briefcase")
        let workspaceCatalog = WorkspaceCatalogSpy()
        let viewModel = WorkspaceDetailViewModel(
            workspaceCatalog: workspaceCatalog,
            saveDebounce: .zero
        )

        viewModel.adopt(workspace)
        viewModel.setActivationPolicy(.close)

        var savedBeforeSwitch = false
        workspaceCatalog.onSwitch = {
            savedBeforeSwitch = workspaceCatalog.updatedWorkspaces.last?.transition.activationPolicy == .close
        }

        await viewModel.runWorkspace(workspace)

        #expect(savedBeforeSwitch)
        #expect(workspaceCatalog.switchedWorkspaceIDs == [workspace.id])
        #expect(viewModel.activeWorkspaceID == workspace.id)
    }

    @Test("A failed update sets the error and leaves operation state clear")
    func updateFailureSetsError() async {
        let workspace = Workspace(name: "Work", symbol: "briefcase")
        let workspaceCatalog = WorkspaceCatalogSpy()
        workspaceCatalog.error = SettingsWorkspaceStoreError.notConnected
        let viewModel = WorkspaceDetailViewModel(
            workspaceCatalog: workspaceCatalog,
            saveDebounce: .zero
        )

        viewModel.adopt(workspace)
        viewModel.setName("Nope")
        await viewModel.pendingSave?.value

        #expect(workspaceCatalog.updatedWorkspaces.map(\.name) == ["Nope"])
        #expect(viewModel.error == .notConnected)
        #expect(viewModel.operationInProgress == nil)
    }

    @Test("Entering a name clears an empty workspace name error")
    func enteringNameClearsEmptyWorkspaceNameError() async {
        let workspace = Workspace(name: "Work", symbol: "briefcase")
        let workspaceCatalog = WorkspaceCatalogSpy()
        workspaceCatalog.error = SettingsWorkspaceStoreError.mutationRejected(.emptyWorkspaceName)
        let viewModel = WorkspaceDetailViewModel(
            workspaceCatalog: workspaceCatalog,
            saveDebounce: .zero
        )
        viewModel.adopt(workspace)

        viewModel.setName(" ")
        await viewModel.pendingSave?.value
        #expect(viewModel.error == .mutationRejected(.emptyWorkspaceName))

        viewModel.setName("Workspace")
        #expect(viewModel.error == nil)

        await viewModel.pendingSave?.value
        #expect(viewModel.error == nil)
        #expect(viewModel.draft?.name == "Workspace")
    }

    @Test("Whitespace does not clear an empty workspace name error")
    func whitespaceKeepsEmptyWorkspaceNameError() async {
        let workspace = Workspace(name: "Work", symbol: "briefcase")
        let workspaceCatalog = WorkspaceCatalogSpy()
        workspaceCatalog.error = SettingsWorkspaceStoreError.mutationRejected(.emptyWorkspaceName)
        let viewModel = WorkspaceDetailViewModel(
            workspaceCatalog: workspaceCatalog,
            saveDebounce: .zero
        )
        viewModel.adopt(workspace)

        viewModel.setName("")
        await viewModel.pendingSave?.value
        #expect(viewModel.error == .mutationRejected(.emptyWorkspaceName))

        viewModel.setName(" \n ")
        #expect(viewModel.error == .mutationRejected(.emptyWorkspaceName))

        await viewModel.pendingSave?.value
        #expect(viewModel.error == .mutationRejected(.emptyWorkspaceName))
        #expect(viewModel.draft?.name == " \n ")
    }

    @Test("Switching workspace clears an empty workspace name error")
    func adoptingAnotherWorkspaceClearsEmptyWorkspaceNameError() async {
        let workspace = Workspace(name: "Work", symbol: "briefcase")
        let workspaceCatalog = WorkspaceCatalogSpy()
        workspaceCatalog.error = SettingsWorkspaceStoreError.mutationRejected(.emptyWorkspaceName)
        let viewModel = WorkspaceDetailViewModel(
            workspaceCatalog: workspaceCatalog,
            saveDebounce: .zero
        )
        viewModel.adopt(workspace)

        viewModel.setName("")
        await viewModel.pendingSave?.value
        #expect(viewModel.error == .mutationRejected(.emptyWorkspaceName))

        viewModel.adopt(Workspace(name: "Home", symbol: "house"))

        #expect(viewModel.error == nil)
        #expect(viewModel.draft?.name == "Home")
    }

    @Test("A debounced terminal command change saves the trimmed command")
    func debouncedTerminalCommandSave() async {
        let workspace = Workspace(name: "Work", symbol: "briefcase")
        let workspaceCatalog = WorkspaceCatalogSpy()
        let viewModel = WorkspaceDetailViewModel(
            workspaceCatalog: workspaceCatalog,
            saveDebounce: .zero
        )

        viewModel.adopt(workspace)
        viewModel.setTerminalCommand("  echo hi  ")
        await viewModel.pendingSave?.value

        #expect(workspaceCatalog.updatedWorkspaces.count == 1)
        #expect(workspaceCatalog.updatedWorkspaces.first?.transition.terminalCommand == "echo hi")
        #expect(viewModel.draft?.transition.terminalCommand == "echo hi")
    }

    @Test("Clearing the terminal command saves nil")
    func clearingTerminalCommandSavesNil() async {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase",
            transition: WorkspaceTransition(terminalCommand: "echo hi")
        )
        let workspaceCatalog = WorkspaceCatalogSpy()
        let viewModel = WorkspaceDetailViewModel(
            workspaceCatalog: workspaceCatalog,
            saveDebounce: .zero
        )

        viewModel.adopt(workspace)
        viewModel.setTerminalCommand("   ")
        await viewModel.pendingSave?.value

        #expect(workspaceCatalog.updatedWorkspaces.count == 1)
        #expect(workspaceCatalog.updatedWorkspaces.first?.transition.terminalCommand == nil)
    }

    @Test("Adopting a snapshot keeps a dirty terminal command")
    func adoptKeepsDirtyTerminalCommand() async {
        let workspace = Workspace(name: "Work", symbol: "briefcase")
        let viewModel = WorkspaceDetailViewModel(
            workspaceCatalog: WorkspaceCatalogSpy(),
            saveDebounce: .zero
        )
        viewModel.adopt(workspace)
        viewModel.setTerminalCommand("echo local")

        var remote = workspace
        remote.transition = WorkspaceTransition(terminalCommand: "echo remote")
        viewModel.adopt(remote)

        #expect(viewModel.draft?.transition.terminalCommand == "echo local")

        await viewModel.pendingSave?.value
        #expect(viewModel.draft?.transition.terminalCommand == "echo local")
    }

    private let sampleApplication = WorkspaceApplication(
        bundleIdentifier: "com.apple.Safari",
        displayName: "Safari"
    )

    private let otherApplication = WorkspaceApplication(
        bundleIdentifier: "com.apple.mail",
        displayName: "Mail"
    )

    private enum TestError: Error { case expected }

    private func makeApplicationBundle(
        name: String,
        bundleIdentifier: String,
        displayName: String
    ) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dawn-app-import-\(UUID().uuidString)", isDirectory: true)
        let contents = root
            .appendingPathComponent("\(name).app", isDirectory: true)
            .appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)

        let info = [
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundleName": name,
            "CFBundleDisplayName": displayName,
            "CFBundlePackageType": "APPL"
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: info,
            format: .xml,
            options: 0
        )
        try data.write(to: contents.appendingPathComponent("Info.plist"))
        return contents.deletingLastPathComponent()
    }
}

@MainActor
private final class WorkspaceCatalogSpy: AppWorkspaceManaging {
    private(set) var switchedWorkspaceIDs: [UUID] = []
    private(set) var stoppedWorkspaceIDs: [UUID] = []
    private(set) var deletedWorkspaceIDs: [UUID] = []
    private(set) var archivedWorkspaceIDs: [UUID] = []
    private(set) var unarchivedWorkspaceIDs: [UUID] = []
    private(set) var updatedWorkspaces: [Workspace] = []

    var error: Error?
    var onSwitch: (() -> Void)?
    var onStop: (() -> Void)?
    var onUnarchive: (() -> Void)?

    func switchWorkspace(id: UUID) async throws {
        switchedWorkspaceIDs.append(id)
        onSwitch?()

        if let error {
            throw error
        }
    }

    func stopWorkspace(id: UUID) async throws {
        stoppedWorkspaceIDs.append(id)
        onStop?()

        if let error {
            throw error
        }
    }

    func deleteWorkspace(id: UUID) async throws {
        deletedWorkspaceIDs.append(id)

        if let error {
            throw error
        }
    }

    func archiveWorkspace(id: UUID) async throws {
        archivedWorkspaceIDs.append(id)

        if let error {
            throw error
        }
    }

    func unarchiveWorkspace(id: UUID) async throws {
        unarchivedWorkspaceIDs.append(id)
        onUnarchive?()

        if let error {
            throw error
        }
    }

    func updateWorkspace(_ workspace: Workspace) async throws {
        updatedWorkspaces.append(workspace)

        if let error {
            throw error
        }
    }
}
