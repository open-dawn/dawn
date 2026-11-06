import libdawn
import libdawnUI
import SwiftUI

struct ContextDetailView: View {
    let context: WorkspaceContext
    let viewModel: ContextDetailViewModel
    let interactionsDisabled: Bool
    let onDelete: (WorkspaceContext) -> Void

    @State private var isApplicationPickerPresented = false

    var isActive: Bool {
        context.id == viewModel.activeContextID
    }

    private var editedContext: WorkspaceContext {
        if let draft = viewModel.draft, draft.id == context.id {
            return draft
        }
        return context
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ContextDetailHeader(
                    name: editedContext.name,
                    symbol: editedContext.symbol,
                    isActive: isActive,
                    isArchived: context.isArchived,
                    interactionsDisabled: interactionsDisabled,
                    onActivate: {
                        Task {
                            await viewModel.runContext(context)
                        }
                    },
                    onArchive: {
                        Task {
                            await viewModel.archiveContext(context)
                        }
                    },
                    onUnarchive: {
                        Task {
                            await viewModel.unarchiveContext(context)
                        }
                    },
                    onDelete: {
                        Task {
                            let deleted = await viewModel.deleteContext(context)
                            if deleted {
                                onDelete(context)
                            }
                        }
                    }
                )

                HStack(alignment: .top, spacing: 32) {
                    ContextDetailNameField(
                        name: editedContext.name,
                        validationMessage: nameValidationMessage
                    ) { newName in
                        viewModel.setName(newName)
                    }

                    ContextDetailSymbolPicker(symbol: editedContext.symbol) { newSymbol in
                        viewModel.setSymbol(newSymbol)
                    }
                }
                .padding(.horizontal, 32)

                ContextDetailApplicationList(
                    applications: editedContext.applications,
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

                ContextDetailActivationPolicyPicker(
                    policy: editedContext.transition.activationPolicy
                ) { policy in
                    viewModel.setActivationPolicy(policy)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onChange(of: context, initial: true) { _, snapshot in
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
            ContextApplicationPicker(
                loadApplications: loadInstalledApplications,
                initialSelection: editedContext.applications.map {
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
        guard viewModel.error?.isEmptyContextName == true else {
            return nil
        }

        guard editedContext.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return viewModel.error?.errorDescription
    }

    private func loadInstalledApplications() async throws -> [ContextCreationApplication] {
        try await ApplicationsDirectoryProvider().applications().map {
            creationApplication(from: $0)
        }
    }

    private func creationApplication(
        from application: WorkspaceApplication
    ) -> ContextCreationApplication {
        ContextCreationApplication(
            id: application.id,
            bundleIdentifier: application.bundleIdentifier,
            displayName: application.displayName,
            applicationURL: application.applicationURL
        )
    }

    private func workspaceApplication(
        from application: ContextCreationApplication
    ) -> WorkspaceApplication {
        WorkspaceApplication(
            id: application.id,
            bundleIdentifier: application.bundleIdentifier,
            displayName: application.displayName,
            applicationURL: application.applicationURL
        )
    }
}
