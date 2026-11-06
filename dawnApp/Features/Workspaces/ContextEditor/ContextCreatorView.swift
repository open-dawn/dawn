import SwiftUI
import libdawn
import libdawnUI

struct ContextCreatorView: View {
    @Environment(SettingsContextStore.self)
    private var contextStore

    @Environment(\.dismiss)
    private var dismiss

    private let applicationProvider: any InstalledApplicationProviding

    init(
        applicationProvider: any InstalledApplicationProviding = ApplicationsDirectoryProvider(),
    ) {
        self.applicationProvider = applicationProvider
    }

    var body: some View {
        ContextCreationFlowView(
            loadApplications: loadApplications,
            createContext: createContext,
            activateContext: activateContext,
            onExit: {
                dismiss()
            }
        )
    }
}

extension ContextCreatorView {
    fileprivate func loadApplications() async throws -> [ContextCreationApplication] {
        try await applicationProvider.applications().map { application in
            ContextCreationApplication(
                id: application.id,
                bundleIdentifier: application.bundleIdentifier,
                displayName: application.displayName,
                applicationURL: application.applicationURL
            )
        }
    }

    fileprivate func createContext(_ request: ContextCreationRequest) async throws -> UUID {
        try await contextStore.createContext(
            name: request.name,
            symbol: request.symbolName,
            applications: request.applications.map { application in
                WorkspaceApplication(
                    id: application.id,
                    bundleIdentifier: application.bundleIdentifier,
                    displayName: application.displayName,
                    applicationURL: application.applicationURL
                )
            }
        )
    }

    fileprivate func activateContext(_ contextID: UUID) async throws {
        try await contextStore.switchContext(id: contextID)
    }
}
