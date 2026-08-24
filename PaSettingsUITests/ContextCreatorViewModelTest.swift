import Testing
import Foundation
@testable import PaSettingsUI

@Suite("ContextCreator ViewModel")
struct ContextCreatorViewModelTests {
    @Test("starts a view model with an empty context")
    func initialState() {
        let viewModel = ContextCreatorView.ViewModel()

        #expect(viewModel.error == nil)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)

        #expect(viewModel.context.name.isEmpty)
        #expect(viewModel.context.icon.isEmpty)
        #expect(viewModel.context.apps.isEmpty)
    }

    @Test("append a new default app")
    func addNewDefaultApp() {
        let viewModel = ContextCreatorView.ViewModel()

        viewModel.addNewDefaultApp()
        #expect(viewModel.context.apps.count == 1)

        let newApp = viewModel.context.apps[0]
        #expect(newApp.name.isEmpty)
    }

    @Test("ignores an unknown app id")
    func removeUnknownAppDoesNothing() {
        let viewModel = ContextCreatorView.ViewModel()

        viewModel.removeApp(UUID())
        #expect(viewModel.context.apps.count == 0)

        viewModel.addNewDefaultApp()
        viewModel.removeApp(UUID())
        #expect(viewModel.context.apps.count == 1)

        #expect(viewModel.error == ViewModelError.invalidAccess)
    }

    @Test("removes the matching app")
    func removeApp() {
        let viewModel = ContextCreatorView.ViewModel()
        viewModel.addNewDefaultApp()
        viewModel.removeApp(viewModel.context.apps[0].id)
        #expect(viewModel.context.apps.count == 0)
    }

    @Test("removing an app keeps the other apps")
    func removeAppLeavesTheOthers() {
        let viewModel = ContextCreatorView.ViewModel()
        viewModel.addNewDefaultApp()
        viewModel.addNewDefaultApp()

        let firstAppId = viewModel.context.apps[0].id
        let secondAppId = viewModel.context.apps[1].id
        viewModel.removeApp(firstAppId)

        #expect(viewModel.context.apps.count == 1)
        #expect(viewModel.context.apps[0].id == secondAppId)
    }
}