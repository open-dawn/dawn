import Foundation

import PaEventKit

import Testing

@testable import PaSettingsUI

@MainActor
@Suite("WorkspaceSwitcher ViewModel")
struct WorkspaceSwitcherViewModelTests {
    @Test("Starts with no active operation, error, or presented creator")
    func initialState() async throws {
        let contextManager = WorkspaceContextManagerSpy()
        let viewModel = WorkspaceSwitcherView.ViewModel(
            contextManager: contextManager
        )

        #expect(viewModel.operationInProgress == nil)
        #expect(viewModel.error == nil)
        #expect(!viewModel.isCreatingOrEditing)
        #expect(viewModel.contextBeingEdited == nil)
    }

    @Test("Presents and dismisses the context creator")
    func contextCreatorPresentation() {
        let contextManager = WorkspaceContextManagerSpy()
        let viewModel = WorkspaceSwitcherView.ViewModel(
            contextManager: contextManager
        )

        viewModel.presentContextCreator()

        #expect(viewModel.isCreatingOrEditing)

        viewModel.dismissContextCreator()

        #expect(!viewModel.isCreatingOrEditing)
    }

    @Test("Run delegates the selected context identifier")
    func runContext() async {
        let context = WorkspaceContext(
            name: "Work",
            symbol: "briefcase"
        )

        let contextManager = WorkspaceContextManagerSpy()
        let viewModel = WorkspaceSwitcherView.ViewModel(
            contextManager: contextManager
        )

        var observedOperationID: UUID?
        contextManager.onSwitch = {
            observedOperationID = viewModel.operationInProgress
        }

        await viewModel.runContext(context)

        #expect(contextManager.switchedContextIDs == [context.id])
        #expect(observedOperationID == context.id)
        #expect(viewModel.operationInProgress == nil)
        #expect(viewModel.error == nil)
    }

    @Test("Delete delegates the selected context identifier")
    func deleteContext() async {
        let context = WorkspaceContext(
            name: "Personal",
            symbol: "person"
        )

        let contextManager = WorkspaceContextManagerSpy()
        let viewModel = WorkspaceSwitcherView.ViewModel(
            contextManager: contextManager
        )

        await viewModel.deleteContext(context)

        #expect(contextManager.deletedContextIDs == [context.id])
        #expect(viewModel.operationInProgress == nil)
        #expect(viewModel.error == nil)
    }

    @Test("A context-manager error is exposed and operation state is cleared")
    func contextManagerError() async {
        let context = WorkspaceContext(
            name: "Work",
            symbol: "briefcase"
        )

        let contextManager = WorkspaceContextManagerSpy()
        contextManager.error = PaSettingsContextStoreError.notConnected

        let viewModel = WorkspaceSwitcherView.ViewModel(
            contextManager: contextManager
        )

        await viewModel.runContext(context)

        #expect(contextManager.switchedContextIDs == [context.id])
        #expect(viewModel.error == .notConnected)
        #expect(viewModel.operationInProgress == nil)
    }

    @Test("A successful operation clears the previous error")
    func successfulOperationClearsError() async {
        let context = WorkspaceContext(
            name: "Work",
            symbol: "briefcase"
        )

        let contextManager = WorkspaceContextManagerSpy()
        contextManager.error = PaSettingsContextStoreError.timeout

        let viewModel = WorkspaceSwitcherView.ViewModel(
            contextManager: contextManager
        )

        await viewModel.runContext(context)

        #expect(viewModel.error == .timeout)

        contextManager.error = nil

        await viewModel.runContext(context)

        #expect(viewModel.error == nil)
        #expect(viewModel.operationInProgress == nil)
    }

    @Test("An unknown error maps to unknown")
    func unknownError() async {
        let context = WorkspaceContext(
            name: "Personal",
            symbol: "person"
        )

        let contextManager = WorkspaceContextManagerSpy()
        contextManager.error = TestError.expected

        let viewModel = WorkspaceSwitcherView.ViewModel(
            contextManager: contextManager
        )

        await viewModel.deleteContext(context)

        #expect(viewModel.error == .unknown)
        #expect(viewModel.operationInProgress == nil)
    }

    @Test("Presents the editor with the selected context")
    func contextEditorPresentation() {
        let context = WorkspaceContext(
            name: "Personal",
            symbol: "person"
        )
        let viewModel = WorkspaceSwitcherView.ViewModel(
            contextManager: WorkspaceContextManagerSpy()
        )

        viewModel.presentContextEditor(context)

        #expect(viewModel.isCreatingOrEditing)
        #expect(viewModel.contextBeingEdited == context)

        viewModel.dismissContextCreator()

        #expect(!viewModel.isCreatingOrEditing)
        #expect(viewModel.contextBeingEdited == nil)
    }

    @Test("Presenting the creator clears the editing context")
    func creatorClearsEditingContext() {
        let context = WorkspaceContext(
            name: "Work",
            symbol: "briefcase"
        )
        let viewModel = WorkspaceSwitcherView.ViewModel(
            contextManager: WorkspaceContextManagerSpy()
        )

        viewModel.presentContextEditor(context)
        viewModel.presentContextCreator()

        #expect(viewModel.isCreatingOrEditing)
        #expect(viewModel.contextBeingEdited == nil)
    }

}
@MainActor
private final class WorkspaceContextManagerSpy: WorkspaceContextManaging {
    private(set) var switchedContextIDs: [UUID] = []
    private(set) var deletedContextIDs: [UUID] = []

    var error: Error?
    var onSwitch: (() -> Void)?

    func switchContext(id: UUID) async throws {
        switchedContextIDs.append(id)
        onSwitch?()

        if let error {
            throw error
        }
    }

    func deleteContext(id: UUID) async throws {
        deletedContextIDs.append(id)

        if let error {
            throw error
        }
    }
}
private enum TestError: Error {
    case expected
}
