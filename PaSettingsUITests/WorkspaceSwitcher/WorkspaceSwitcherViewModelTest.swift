@testable import PaSettingsUI
import Testing

@Suite("WorkspaceSwitcher ViewModel")
struct WorkspaceSwitcherViewModelTests {
    @Test("starts a view model with no modal")
    func initialState() {
        let viewModel = WorkspaceSwitcherView.ViewModel()

        #expect(viewModel.error == nil)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.isCreatingOrEditing == false)
    }

    @Test("fetch contexts success doesnt throw error")
    func fetchContextsSuccess() {
        let viewModel = WorkspaceSwitcherView.ViewModel()
        try? viewModel.fetchContexts()

        #expect(viewModel.error == nil)
        #expect(viewModel.errorMessage == nil)
    }
}