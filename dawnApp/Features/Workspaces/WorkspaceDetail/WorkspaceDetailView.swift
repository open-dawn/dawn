import libdawn
import libdawnUI
import SwiftUI

struct WorkspaceDetailView: View {
    let workspace: Workspace
    let viewModel: WorkspaceDetailViewModel
    let interactionsDisabled: Bool
    let onDelete: (Workspace) -> Void

    @State private var isApplicationPickerPresented = false

    var isActive: Bool {
        workspace.id == viewModel.activeWorkspaceID
    }

    private var editedWorkspace: Workspace {
        if let draft = viewModel.draft, draft.id == workspace.id {
            return draft
        }
        return workspace
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                WorkspaceDetailHeader(
                    name: editedWorkspace.name,
                    symbol: editedWorkspace.symbol,
                    isActive: isActive,
                    isArchived: workspace.isArchived,
                    interactionsDisabled: interactionsDisabled,
                    onActivate: {
                        Task {
                            await viewModel.runWorkspace(workspace)
                        }
                    },
                    onArchive: {
                        Task {
                            await viewModel.archiveWorkspace(workspace)
                        }
                    },
                    onUnarchive: {
                        Task {
                            await viewModel.unarchiveWorkspace(workspace)
                        }
                    },
                    onDelete: {
                        Task {
                            let deleted = await viewModel.deleteWorkspace(workspace)
                            if deleted {
                                onDelete(workspace)
                            }
                        }
                    },
                    onStop: {
                        Task {
                            await viewModel.stopWorkspace(workspace)
                        }
                    }
                )

                VStack(alignment: .leading, spacing: 16) {
                    WorkspaceDetailNameField(
                        name: editedWorkspace.name,
                        validationMessage: nameValidationMessage,
                        interactionsDisabled: interactionsDisabled,
                    ) { newName in
                        viewModel.setName(newName)
                    }
                    .padding(.horizontal, 32)

                    WorkspaceDetailSymbolPicker(
                        symbol: editedWorkspace.symbol,
                        interactionsDisabled: interactionsDisabled
                    ) { newSymbol in
                        viewModel.setSymbol(newSymbol)
                    }
                    .padding(.horizontal, 32)
                }

                WorkspaceDetailApplicationList(
                    applications: editedWorkspace.applications,
                    interactionsDisabled: interactionsDisabled,
                    onAddApplications: {
                        isApplicationPickerPresented = true
                    },
                    onRemoveApplication: { application in
                        viewModel.removeApplication(id: application.id)
                    },
                    onDropApplications: { urls in
                        viewModel.addApplications(at: urls)
                    }
                )

                WorkspaceDetailActivationPolicyPicker(
                    policy: editedWorkspace.transition.activationPolicy,
                    interactionsDisabled: interactionsDisabled
                ) { policy in
                    viewModel.setActivationPolicy(policy)
                }

                WorkspaceDetailTerminalCommandField(
                    command: editedWorkspace.transition.terminalCommand ?? "",
                    interactionsDisabled: interactionsDisabled
                ) { command in
                    viewModel.setTerminalCommand(command)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onChange(of: workspace, initial: true) { _, snapshot in
                viewModel.adopt(snapshot)
            }
        }
        .alert(
            "Couldn't Add Application",
            isPresented: Binding(
                get: { viewModel.applicationImportError != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.dismissApplicationImportError()
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                viewModel.dismissApplicationImportError()
            }
        } message: {
            Text(viewModel.applicationImportError?.localizedDescription ?? "")
        }
        .sheet(isPresented: $isApplicationPickerPresented) {
            WorkspaceApplicationPicker(
                loadApplications: loadInstalledApplications,
                initialSelection: editedWorkspace.applications.map {
                    creationApplication(from: $0)
                },
                confirmTitle: "Add",
                onConfirm: { selected in
                    viewModel.applyApplicationSelection(
                        selected.map { workspaceApplication(from: $0) }
                    )
                    isApplicationPickerPresented = false
                },
                onCancel: {
                    isApplicationPickerPresented = false
                }
            )
            .padding(16)
            .frame(width: 320, height: 600)
            .background {
                DawnColors.primaryBackground
                    .ignoresSafeArea()
            }
            .presentationBackground(DawnColors.primaryBackground)
        }
    }

    private var nameValidationMessage: String? {
        guard viewModel.error?.isEmptyWorkspaceName == true else {
            return nil
        }

        guard editedWorkspace.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return viewModel.error?.errorDescription
    }

    private func loadInstalledApplications() async throws -> [WorkspaceCreationApplication] {
        try await ApplicationsDirectoryProvider().applications().map {
            creationApplication(from: $0)
        }
    }

    private func creationApplication(
        from application: WorkspaceApplication
    ) -> WorkspaceCreationApplication {
        WorkspaceCreationApplication(
            id: application.id,
            bundleIdentifier: application.bundleIdentifier,
            displayName: application.displayName,
            applicationURL: application.applicationURL
        )
    }

    private func workspaceApplication(
        from application: WorkspaceCreationApplication
    ) -> WorkspaceApplication {
        WorkspaceApplication(
            id: application.id,
            bundleIdentifier: application.bundleIdentifier,
            displayName: application.displayName,
            applicationURL: application.applicationURL
        )
    }
}
