//
//  MenuBarContextCreationView.swift
//  dawn
//
//  Created by Longhi on 03/11/26.
//

import SwiftUI
import libdawn
import libdawnUI

struct MenuBarContextCreationView: View {
    let workspace: WorkspaceRuntime
    let onExit: () -> Void

    private let applicationProvider: any InstalledApplicationProviding
    private let modalPresentationState: MenuBarModalPresentationState

    init(
        workspace: WorkspaceRuntime,
        modalPresentationState: MenuBarModalPresentationState,
        applicationProvider: any InstalledApplicationProviding = ApplicationsDirectoryProvider(),
        onExit: @escaping () -> Void
    ) {
        self.workspace = workspace
        self.modalPresentationState = modalPresentationState
        self.applicationProvider = applicationProvider
        self.onExit = onExit
    }

    var body: some View {
        ContextCreationFlowView(
            loadApplications: loadApplications,
            createContext: createContext,
            activateContext: activateContext,
            onExit: onExit,
            onModalPresentationChange: updateModalPresentation
        )
    }
}

extension MenuBarContextCreationView {
    private func loadApplications() async throws -> [ContextCreationApplication] {
        try await applicationProvider.applications().map { application in
            ContextCreationApplication(
                id: application.id,
                bundleIdentifier: application.bundleIdentifier,
                displayName: application.displayName,
                applicationURL: application.applicationURL
            )
        }
    }

    private func createContext(_ request: ContextCreationRequest) async throws -> UUID {
        let context = try await workspace.createContext(
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

        return context.id
    }

    private func activateContext(_ contextID: UUID) async throws {
        try await workspace.activateContext(id: contextID)
    }

    private func updateModalPresentation(
        _ modal: ContextCreationModal,
        _ isPresented: Bool
    ) {
        let presentation: MenuBarModalPresentationState.Presentation =
            switch modal {
            case .operationError:
                .contextCreationError
            case .applicationImporter:
                .applicationImporter
            }

        modalPresentationState.setPresented(isPresented, for: presentation)
    }
}
