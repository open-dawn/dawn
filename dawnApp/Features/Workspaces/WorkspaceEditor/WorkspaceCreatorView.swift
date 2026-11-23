import SwiftUI
import libdawn
import libdawnUI

struct WorkspaceCreatorView: View {
    @Environment(SettingsWorkspaceStore.self)
    private var workspaceStore

    @Environment(\.dismiss)
    private var dismiss

    private let applicationProvider: any InstalledApplicationProviding

    init(
        applicationProvider: any InstalledApplicationProviding = ApplicationsDirectoryProvider(),
    ) {
        self.applicationProvider = applicationProvider
    }

    var body: some View {
        WorkspaceCreationFlowView(
            loadApplications: loadApplications,
            createWorkspace: createWorkspace,
            activateWorkspace: activateWorkspace,
            onExit: {
                dismiss()
            }
        )
    }
}

extension WorkspaceCreatorView {
    fileprivate func loadApplications() async throws -> [WorkspaceCreationApplication] {
        try await applicationProvider.applications().map { application in
            WorkspaceCreationApplication(
                id: application.id,
                bundleIdentifier: application.bundleIdentifier,
                displayName: application.displayName,
                applicationURL: application.applicationURL
            )
        }
    }

    fileprivate func createWorkspace(_ request: WorkspaceCreationRequest) async throws -> UUID {
        try await workspaceStore.createWorkspace(
            name: request.name,
            symbol: request.symbolName,
            applications: request.applications.map { application in
                WorkspaceApplication(
                    id: application.id,
                    bundleIdentifier: application.bundleIdentifier,
                    displayName: application.displayName,
                    applicationURL: application.applicationURL
                )
            },
            transition: request.transition
        )
    }

    fileprivate func activateWorkspace(_ workspaceID: UUID) async throws {
        try await workspaceStore.switchWorkspace(id: workspaceID)
    }
}
