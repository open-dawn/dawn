import Foundation

import PaEventKit

import Testing

@testable import PaSettingsUI

@MainActor
@Suite("ContextCreator ViewModel")
struct ContextCreatorViewModelTests {
    @Test("starts a view model with an empty context")
    func initialState() {
        let contextCreator = ContextCreatorSpy()
        let viewModel = ContextCreatorView.ViewModel(contextCreator: contextCreator)

        #expect(viewModel.error == nil)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)

        #expect(viewModel.context.name.isEmpty)
        #expect(viewModel.context.symbol.isEmpty)
        #expect(viewModel.context.applications.isEmpty)
    }

    @Test("Adds the selected application")
    func addSelectedApplication() async {
        let application = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            applicationURL: URL(fileURLWithPath: "/Applications/Safari.app")
        )

        let selector = ApplicationSelectorSpy(result: application)
        let viewModel = ContextCreatorView.ViewModel(
            contextCreator: ContextCreatorSpy(),
            applicationSelector: selector
        )

        await viewModel.addApplication()

        #expect(selector.callCount == 1)
        #expect(viewModel.context.applications == [application])
        #expect(viewModel.applicationSelectionError == nil)
        #expect(!viewModel.isLoading)
    }

    @Test("Cancelling application selection changes nothing")
    func cancelApplicationSelection() async {
        let selector = ApplicationSelectorSpy(result: nil)
        let viewModel = ContextCreatorView.ViewModel(
            contextCreator: ContextCreatorSpy(),
            applicationSelector: selector
        )

        await viewModel.addApplication()

        #expect(selector.callCount == 1)
        #expect(viewModel.context.applications.isEmpty)
        #expect(viewModel.applicationSelectionError == nil)
        #expect(!viewModel.isLoading)
    }

    @Test("Exposes application-selection errors")
    func applicationSelectionError() async {
        let selector = ApplicationSelectorSpy(
            error: ApplicationSelectionError.missingBundleIdentifier
        )
        let viewModel = ContextCreatorView.ViewModel(
            contextCreator: ContextCreatorSpy(),
            applicationSelector: selector
        )

        await viewModel.addApplication()

        #expect(viewModel.context.applications.isEmpty)
        #expect(
            viewModel.applicationSelectionError
                == .missingBundleIdentifier
        )
        #expect(!viewModel.isLoading)
    }

    @Test("Maps an unexpected application-selection error")
    func unknownApplicationSelectionError() async {
        let selector = ApplicationSelectorSpy(error: TestError.expected)
        let viewModel = ContextCreatorView.ViewModel(
            contextCreator: ContextCreatorSpy(),
            applicationSelector: selector
        )

        await viewModel.addApplication()

        #expect(viewModel.context.applications.isEmpty)
        #expect(viewModel.applicationSelectionError == .unknown)
        #expect(!viewModel.isLoading)
    }

    @Test("Exposes loading state while selecting an application")
    func applicationSelectionLoadingState() async {
        let selector = ApplicationSelectorSpy()
        let viewModel = ContextCreatorView.ViewModel(
            contextCreator: ContextCreatorSpy(),
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
        let viewModel = ContextCreatorView.ViewModel(
            contextCreator: ContextCreatorSpy(),
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

        let viewModel = ContextCreatorView.ViewModel(
            contextCreator: ContextCreatorSpy()
        )
        viewModel.context.applications = [application]

        viewModel.removeApp(UUID())

        #expect(viewModel.context.applications == [application])
        #expect(viewModel.error == .invalidAccess)
    }

    @Test("Removes the matching application")
    func removeApplication() {
        let application = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari"
        )

        let viewModel = ContextCreatorView.ViewModel(
            contextCreator: ContextCreatorSpy()
        )
        viewModel.context.applications = [application]

        viewModel.removeApp(application.id)

        #expect(viewModel.context.applications.isEmpty)
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

        let viewModel = ContextCreatorView.ViewModel(
            contextCreator: ContextCreatorSpy()
        )
        viewModel.context.applications = [safari, mail]

        viewModel.removeApp(safari.id)

        #expect(viewModel.context.applications == [mail])
    }

    @Test("Save delegates the context information")
    func saveContexDelefatesContext() async throws {
        let application = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari"
        )

        let contextCreator = ContextCreatorSpy()
        let viewModel = ContextCreatorView.ViewModel(
            contextCreator: contextCreator
        )

        viewModel.context.name = "Work"
        viewModel.context.symbol = "briefcase"
        viewModel.context.applications = [application]

        let succeeded = await viewModel.saveContext()

        #expect(succeeded)
        #expect(
            contextCreator.requests == [
                ContextCreatorSpy.Request(
                    name: "Work",
                    symbol: "briefcase",
                    applications: [application]
                )
            ]
        )
        #expect(viewModel.saveError == nil)
        #expect(!viewModel.isLoading)
    }

    @Test("Save exposes loading state during creation")
    func saveContextLoadingState() async {
        let contextCreator = ContextCreatorSpy()
        let viewModel = ContextCreatorView.ViewModel(
            contextCreator: contextCreator
        )

        var observedLoadingState = false

        contextCreator.onCreate = {
            observedLoadingState = viewModel.isLoading
        }

        let succeeded = await viewModel.saveContext()

        #expect(succeeded)
        #expect(observedLoadingState)
        #expect(!viewModel.isLoading)
    }

    @Test("Save exposes a context-store error")
    func saveContextStoreError() async {
        let contextCreator = ContextCreatorSpy()
        contextCreator.error = PaSettingsContextStoreError.mutationRejected(
            .emptyContextName
        )

        let viewModel = ContextCreatorView.ViewModel(
            contextCreator: contextCreator
        )

        let succeeded = await viewModel.saveContext()

        #expect(!succeeded)
        #expect(
            viewModel.saveError
                == .mutationRejected(.emptyContextName)
        )
        #expect(!viewModel.isLoading)
    }

    @Test("Save maps an unknown error")
    func saveContextUnknownError() async {
        let contextCreator = ContextCreatorSpy()
        contextCreator.error = TestError.expected

        let viewModel = ContextCreatorView.ViewModel(
            contextCreator: contextCreator
        )

        let succeeded = await viewModel.saveContext()

        #expect(!succeeded)
        #expect(viewModel.saveError == .unknown)
        #expect(!viewModel.isLoading)
    }

    @Test("A successful save clears the previous error")
    func successfulSaveClearsError() async {
        let contextCreator = ContextCreatorSpy()
        contextCreator.error = PaSettingsContextStoreError.timeout

        let viewModel = ContextCreatorView.ViewModel(
            contextCreator: contextCreator
        )

        #expect(await viewModel.saveContext() == false)
        #expect(viewModel.saveError == .timeout)

        contextCreator.error = nil

        #expect(await viewModel.saveContext())
        #expect(viewModel.saveError == nil)
    }

    @Test("Dismiss save error clears the current error")
    func dismissSaveError() async {
        let contextCreator = ContextCreatorSpy()
        contextCreator.error = PaSettingsContextStoreError.notConnected

        let viewModel = ContextCreatorView.ViewModel(
            contextCreator: contextCreator
        )

        _ = await viewModel.saveContext()
        #expect(viewModel.saveError == .notConnected)

        viewModel.dismissSaveError()

        #expect(viewModel.saveError == nil)
    }
}
@MainActor
private final class ContextCreatorSpy: ContextCreating {
    struct Request: Equatable {
        let name: String
        let symbol: String
        let applications: [WorkspaceApplication]
    }

    private(set) var requests: [Request] = []

    var returnedID = UUID()
    var error: Error?
    var onCreate: (() -> Void)?

    func createContext(
        name: String,
        symbol: String,
        applications: [WorkspaceApplication]
    ) async throws -> UUID {
        requests.append(
            Request(
                name: name,
                symbol: symbol,
                applications: applications
            )
        )

        onCreate?()

        if let error {
            throw error
        }

        return returnedID
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
