import Testing
import Foundation
@testable import PaSettingsUI

@Suite("ContextCreator ViewModel")
struct ContextCreatorViewModelTests{
    @Test("starts a view model with an empty context")
    func initialState() {
        let vm = ContextCreatorView.ViewModel()
    
        #expect(vm.error == nil)
        #expect(vm.errorMessage == nil)
        #expect(vm.isLoading == false)

        #expect(vm.context.name.isEmpty)
        #expect(vm.context.icon.isEmpty)
        #expect(vm.context.apps.isEmpty)
    }
    
    @Test("append a new default app")
    func addNewDefaultApp() {
        let vm = ContextCreatorView.ViewModel()
        
        vm.addNewDefaultApp()
        #expect(vm.context.apps.count == 1)
        
        let newApp = vm.context.apps[0]
        #expect(newApp.name.isEmpty)
    }
    
    @Test("ignores an unknown app id")
    func removeUnknownAppDoesNothing() {
        let vm = ContextCreatorView.ViewModel()
        
        vm.removeApp(UUID())
        #expect(vm.context.apps.count == 0)
    
        vm.addNewDefaultApp()
        vm.removeApp(UUID())
        #expect(vm.context.apps.count == 1)
    }
    
    @Test("removes the matching app")
    func removeApp() {
        let vm = ContextCreatorView.ViewModel()
        vm.addNewDefaultApp()
        vm.removeApp(vm.context.apps[0].id)
        #expect(vm.context.apps.count == 0)
    }

    @Test("removing an app keeps the other apps")
    func removeAppLeavesTheOthers() {
        let vm = ContextCreatorView.ViewModel()
        vm.addNewDefaultApp()
        vm.addNewDefaultApp()

        let firstAppId = vm.context.apps[0].id
        let secondAppId = vm.context.apps[1].id
        vm.removeApp(firstAppId)

        #expect(vm.context.apps.count == 1)
        #expect(vm.context.apps[0].id == secondAppId)
    }
}
