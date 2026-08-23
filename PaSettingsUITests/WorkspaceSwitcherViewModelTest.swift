import Testing
@testable import PaSettingsUI

@Suite("WorkspaceSwitcher ViewModel")
struct WorkspaceSwitcherViewModelTests{
    @Test("starts a view model with no modal")
    func initialState() {
        let vm = WorkspaceSwitcherView.ViewModel()
    
        #expect(vm.error == nil)
        #expect(vm.errorMessage == nil)
        #expect(vm.isLoading == false)
        #expect(vm.isCreatingOrEditing == false)
    }

    @Test("fetch contexts success doesnt throw error")
    func fetchContextsSuccess() {
        let vm = WorkspaceSwitcherView.ViewModel()
        try? vm.fetchContexts()

        #expect(vm.error == nil)
        #expect(vm.errorMessage == nil)
    }
}
