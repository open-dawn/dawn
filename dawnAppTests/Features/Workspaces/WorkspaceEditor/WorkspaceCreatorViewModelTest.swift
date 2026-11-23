import Foundation
import libdawn
import Testing
@testable import dawnApp

@MainActor
@Suite("WorkspaceCreator ViewModel")
struct WorkspaceCreatorViewModelTests {
    @Test("starts a view model with an empty workspace")
    func initialState() {
        let workspaceCreator = WorkspaceCreatorSpy()
        let viewModel = WorkspaceCreatorViewModel(workspaceSaver: workspaceCreator)

        #expect(viewModel.error == nil)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)

        #expect(viewModel.workspace.name.isEmpty)
        #expect(viewModel.workspace.symbol.isEmpty)
        #expect(viewModel.workspace.applications.isEmpty)

        #expect(!viewModel.isEditing)
    }

    @Test("Adds the selected application")
    func addSelectedApplication() async {
        let application = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            applicationURL: URL(fileURLWithPath: "/Applications/Safari.app")
        )

        let selector = ApplicationSelectorSpy(result: application)
        let viewModel = WorkspaceCreatorViewModel(
            workspaceSaver: WorkspaceCreatorSpy(),
            applicationSelector: selector
        )

        await viewModel.addApplication()

        #expect(selector.callCount == 1)
        #expect(viewModel.workspace.applications == [application])
        #expect(viewModel.applicationSelectionError == nil)
        #expect(!viewModel.isLoading)
    }

    @Test("Cancelling application selection changes nothing")
    func cancelApplicationSelection() async {
        let selector = ApplicationSelectorSpy(result: nil)
        let viewModel = WorkspaceCreatorViewModel(
            workspaceSaver: WorkspaceCreatorSpy(),
            applicationSelector: selector
        )

        await viewModel.addApplication()

        #expect(selector.callCount == 1)
        #expect(viewModel.workspace.applications.isEmpty)
        #expect(viewModel.applicationSelectionError == nil)
        #expect(!viewModel.isLoading)
    }

    @Test("Exposes application-selection errors")
    func applicationSelectionError() async {
        let selector = ApplicationSelectorSpy(
            error: ApplicationSelectionError.missingBundleIdentifier
        )
        let viewModel = WorkspaceCreatorViewModel(
            workspaceSaver: WorkspaceCreatorSpy(),
            applicationSelector: selector
        )

        await viewModel.addApplication()

        #expect(viewModel.workspace.applications.isEmpty)
        #expect(viewModel.applicationSelectionError == .missingBundleIdentifier)
        #expect(!viewModel.isLoading)
    }

    @Test("Maps an unexpected application-selection error")
    func unknownApplicationSelectionError() async {
        let selector = ApplicationSelectorSpy(error: TestError.expected)
        let viewModel = WorkspaceCreatorViewModel(
            workspaceSaver: WorkspaceCreatorSpy(),
            applicationSelector: selector
        )

        await viewModel.addApplication()

        #expect(viewModel.workspace.applications.isEmpty)
        #expect(viewModel.applicationSelectionError == .unknown)
        #expect(!viewModel.isLoading)
    }

    @Test("Exposes loading state while selecting an application")
    func applicationSelectionLoadingState() async {
        let selector = ApplicationSelectorSpy()
        let viewModel = WorkspaceCreatorViewModel(
            workspaceSaver: WorkspaceCreatorSpy(),
            applicationSelector: selector
        )

        var observedLoadingState = false
        selector.onSelect = {
            observedLoadingState = viewModel.isLoading
        }

        await viewModel.addApplication()

        #expect(observedLoadingState)
        #expect(!viewModel.isLoading)
    }

    @Test("Dismisses the application-selection error")
    func dismissApplicationSelectionError() async {
        let selector = ApplicationSelectorSpy(
            error: ApplicationSelectionError.invalidApplication
        )
        let viewModel = WorkspaceCreatorViewModel(
            workspaceSaver: WorkspaceCreatorSpy(),
            applicationSelector: selector
        )

        await viewModel.addApplication()
        #expect(viewModel.applicationSelectionError == .invalidApplication)

        viewModel.dismissApplicationSelectionError()

        #expect(viewModel.applicationSelectionError == nil)
    }

    @Test("Ignores an unknown application identifier")
    func removeUnknownApplication() {
        let application = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari"
        )

        let viewModel = WorkspaceCreatorViewModel(
            workspaceSaver: WorkspaceCreatorSpy()
        )
        viewModel.workspace.applications = [application]

        viewModel.removeApp(UUID())

        #expect(viewModel.workspace.applications == [application])
        #expect(viewModel.error == .invalidAccess)
    }

    @Test("Removes the matching application")
    func removeApplication() {
        let application = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari"
        )

        let viewModel = WorkspaceCreatorViewModel(
            workspaceSaver: WorkspaceCreatorSpy()
        )
        viewModel.workspace.applications = [application]

        viewModel.removeApp(application.id)

        #expect(viewModel.workspace.applications.isEmpty)
    }

    @Test("Removing an application preserves the others")
    func removeApplicationPreservesOthers() {
        let safari = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari"
        )
        let mail = WorkspaceApplication(
            bundleIdentifier: "com.apple.mail",
            displayName: "Mail"
        )

        let viewModel = WorkspaceCreatorViewModel(
            workspaceSaver: WorkspaceCreatorSpy()
        )
        viewModel.workspace.applications = [safari, mail]

        viewModel.removeApp(safari.id)

        #expect(viewModel.workspace.applications == [mail])
    }

    @Test("Save delegates the workspace information")
    func saveContexDelefatesWorkspace() async throws {
        let application = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari"
        )

        let workspaceCreator = WorkspaceCreatorSpy()
        let viewModel = WorkspaceCreatorViewModel(
            workspaceSaver: workspaceCreator
        )

        viewModel.workspace.name = "Work"
        viewModel.workspace.symbol = "briefcase"
        viewModel.workspace.applications = [application]

        let succeeded = await viewModel.saveWorkspace()

        #expect(succeeded)
        #expect(
            workspaceCreator.requests == [
                WorkspaceCreatorSpy.Request(
                    name: "Work",
                    symbol: "briefcase",
                    applications: [application],
                    transition: .default
                )
            ]
        )
        #expect(viewModel.saveError == nil)
        #expect(!viewModel.isLoading)
    }

    @Test("Save exposes loading state during creation")
    func saveWorkspaceLoadingState() async {
        let workspaceCreator = WorkspaceCreatorSpy()
        let viewModel = WorkspaceCreatorViewModel(
            workspaceSaver: workspaceCreator
        )

        var observedLoadingState = false

        workspaceCreator.onCreate = {
            observedLoadingState = viewModel.isLoading
        }

        let succeeded = await viewModel.saveWorkspace()

        #expect(succeeded)
        #expect(observedLoadingState)
        #expect(!viewModel.isLoading)
    }

    @Test("Save exposes a workspace-store error")
    func saveWorkspaceStoreError() async {
        let workspaceCreator = WorkspaceCreatorSpy()
        workspaceCreator.error = SettingsWorkspaceStoreError.mutationRejected(
            .emptyWorkspaceName
        )

        let viewModel = WorkspaceCreatorViewModel(
            workspaceSaver: workspaceCreator
        )

        let succeeded = await viewModel.saveWorkspace()

        #expect(!succeeded)
        #expect(
            viewModel.saveError
                == .mutationRejected(.emptyWorkspaceName)
        )
        #expect(!viewModel.isLoading)
    }

    @Test("Save maps an unknown error")
    func saveWorkspaceUnknownError() async {
        let workspaceCreator = WorkspaceCreatorSpy()
        workspaceCreator.error = TestError.expected

        let viewModel = WorkspaceCreatorViewModel(
            workspaceSaver: workspaceCreator
        )

        let succeeded = await viewModel.saveWorkspace()

        #expect(!succeeded)
        #expect(viewModel.saveError == .unknown)
        #expect(!viewModel.isLoading)
    }

    @Test("A successful save clears the previous error")
    func successfulSaveClearsError() async {
        let workspaceCreator = WorkspaceCreatorSpy()
        workspaceCreator.error = SettingsWorkspaceStoreError.timeout

        let viewModel = WorkspaceCreatorViewModel(
            workspaceSaver: workspaceCreator
        )

        #expect(await viewModel.saveWorkspace() == false)
        #expect(viewModel.saveError == .timeout)

        workspaceCreator.error = nil

        #expect(await viewModel.saveWorkspace())
        #expect(viewModel.saveError == nil)
    }

    @Test("Dismiss save error clears the current error")
    func dismissSaveError() async {
        let workspaceCreator = WorkspaceCreatorSpy()
        workspaceCreator.error = SettingsWorkspaceStoreError.notConnected

        let viewModel = WorkspaceCreatorViewModel(
            workspaceSaver: workspaceCreator
        )

        _ = await viewModel.saveWorkspace()
        #expect(viewModel.saveError == .notConnected)

        viewModel.dismissSaveError()

        #expect(viewModel.saveError == nil)
    }

    @Test("Starts edit mode with the existing workspace")
    func editInitialState() {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase",
            applications: [
                WorkspaceApplication(
                    bundleIdentifier: "com.apple.Safari",
                    displayName: "Safari"
                )
            ]
        )

        let viewModel = WorkspaceCreatorViewModel(
            workspaceSaver: WorkspaceCreatorSpy(),
            workspace: workspace
        )

        #expect(viewModel.isEditing)
        #expect(viewModel.workspace == workspace)
    }

    @Test("Saving an edited workspace delegates the complete workspace")
    func saveEditedWorkspace() async {
        let original = Workspace(
            name: "Work",
            symbol: "briefcase"
        )

        let workspaceSaver = WorkspaceCreatorSpy()
        let viewModel = WorkspaceCreatorViewModel(
            workspaceSaver: workspaceSaver,
            workspace: original
        )

        viewModel.workspace.name = "Updated Work"
        viewModel.workspace.symbol = "desktopcomputer"

        let expectedWorkspace = viewModel.workspace
        let succeeded = await viewModel.saveWorkspace()

        #expect(succeeded)
        #expect(workspaceSaver.requests.isEmpty)
        #expect(workspaceSaver.updatedWorkspaces == [expectedWorkspace])
        #expect(expectedWorkspace.id == original.id)
        #expect(viewModel.saveError == nil)
        #expect(!viewModel.isLoading)
    }

    @Test("An update failure is exposed")
    func updateWorkspaceFailure() async {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )
        let expectedError = SettingsWorkspaceStoreError.mutationRejected(
            .workspaceNotFound(workspace.id)
        )

        let workspaceSaver = WorkspaceCreatorSpy()
        workspaceSaver.error = expectedError

        let viewModel = WorkspaceCreatorViewModel(
            workspaceSaver: workspaceSaver,
            workspace: workspace
        )

        let succeeded = await viewModel.saveWorkspace()

        #expect(!succeeded)
        #expect(workspaceSaver.requests.isEmpty)
        #expect(workspaceSaver.updatedWorkspaces == [workspace])
        #expect(viewModel.saveError == expectedError)
        #expect(!viewModel.isLoading)
    }
}
@MainActor
private final class WorkspaceCreatorSpy: WorkspaceSaving {

    struct Request: Equatable {
        let name: String
        let symbol: String
        let applications: [WorkspaceApplication]
        let transition: WorkspaceTransition
    }

    private(set) var requests: [Request] = []
    private(set) var updatedWorkspaces: [Workspace] = []

    var returnedID = UUID()
    var error: Error?
    var onCreate: (() -> Void)?
    var onUpdate: (() -> Void)?

    func createWorkspace(
        name: String,
        symbol: String,
        applications: [WorkspaceApplication],
        transition: WorkspaceTransition
    ) async throws -> UUID {
        requests.append(
            Request(
                name: name,
                symbol: symbol,
                applications: applications,
                transition: transition
            )
        )

        onCreate?()

        if let error {
            throw error
        }

        return returnedID
    }

    func updateWorkspace(_ workspace: libdawn.Workspace) async throws {
        updatedWorkspaces.append(workspace)
        onUpdate?()

        if let error {
            throw error
        }
    }
}
@MainActor
private final class ApplicationSelectorSpy: ApplicationSelecting {
    private let result: WorkspaceApplication?
    private let error: Error?

    private(set) var callCount = 0
    var onSelect: (() -> Void)?

    init(result: WorkspaceApplication? = nil, error: Error? = nil) {
        self.result = result
        self.error = error
    }

    func selectApplication() async throws -> WorkspaceApplication? {
        callCount += 1
        onSelect?()

        if let error {
            throw error
        }

        return result
    }
}
private enum TestError: Error {
    case expected
}
