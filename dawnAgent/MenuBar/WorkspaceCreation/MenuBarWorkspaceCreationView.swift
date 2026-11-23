//
//  MenuBarWorkspaceCreationView.swift
//  dawn
//
//  Created by Longhi on 03/11/26.
//

import SwiftUI
import libdawn
import libdawnUI

struct MenuBarWorkspaceCreationView: View {
    let workspace: WorkspaceRuntime
    let onExit: @MainActor () -> Void

    private let applicationProvider: any InstalledApplicationProviding
    private let modalPresentationState: MenuBarModalPresentationState

    init(
        workspace: WorkspaceRuntime,
        modalPresentationState: MenuBarModalPresentationState,
        applicationProvider: any InstalledApplicationProviding = ApplicationsDirectoryProvider(),
        onExit: @escaping @MainActor () -> Void
    ) {
        self.workspace = workspace
        self.modalPresentationState = modalPresentationState
        self.applicationProvider = applicationProvider
        self.onExit = onExit
    }

    var body: some View {
        WorkspaceCreationFlowView(
            loadApplications: loadApplications,
            createWorkspace: createWorkspace,
            activateWorkspace: activateWorkspace,
            onExit: onExit,
            onModalPresentationChange: updateModalPresentation
        )
    }
}

extension MenuBarWorkspaceCreationView {
    private func loadApplications() async throws -> [WorkspaceCreationApplication] {
        try await applicationProvider.applications().map { application in
            WorkspaceCreationApplication(
                id: application.id,
                bundleIdentifier: application.bundleIdentifier,
                displayName: application.displayName,
                applicationURL: application.applicationURL
            )
        }
    }

    private func createWorkspace(_ request: WorkspaceCreationRequest) async throws -> UUID {
        let created = try await workspace.createWorkspace(
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

        return created.id
    }

    private func activateWorkspace(_ workspaceID: UUID) async throws {
        try await workspace.activateWorkspace(id: workspaceID)
    }

    private func updateModalPresentation(
        _ modal: WorkspaceCreationModal,
        _ isPresented: Bool
    ) {
        let presentation: MenuBarModalPresentationState.Presentation =
            switch modal {
            case .operationError:
                .workspaceCreationError
            case .applicationImporter:
                .applicationImporter
            }

        modalPresentationState.setPresented(isPresented, for: presentation)
    }
}
