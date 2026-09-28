import SwiftUI

struct WorkspaceSwitcherView: View {
    @Environment(PaSettingsContextStore.self)
    private var contextStore

    var body: some View {
        WorkspaceSwitcherContent(store: contextStore)
    }
}

private struct WorkspaceSwitcherContent: View {
    let store: PaSettingsContextStore
    @State private var viewModel: WorkspaceSwitcherView.ViewModel

    @Environment(PaSettingsEventBusService.self)
    private var eventBusService

    private var interactionsDisabled: Bool {
        !eventBusService.isConnected || store.isLoading || viewModel.operationInProgress != nil
    }

    init(store: PaSettingsContextStore) {
        self.store = store
        _viewModel = State(
            initialValue: WorkspaceSwitcherView.ViewModel(
                contextManager: store
            )
        )
    }

    var body: some View {
        VStack {
            if !eventBusService.isConnected {
                Label("Workspace manager is not connected. Context actions are unavailable.", systemImage: "bolt.slash")
                    .foregroundStyle(.orange)
            }

            if let error = viewModel.error ?? store.error {
                HStack {
                    Label(error.localizedDescription, systemImage: "exclamationmark.triangle")

                    Spacer()

                    Button("Dismiss") {
                        viewModel.dismissError()
                        store.dismissError()
                    }
                }
                .foregroundStyle(.red)
            }

            if store.isLoading && store.contexts.isEmpty {
                ProgressView("Loading contexts...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.contexts.isEmpty {
                Spacer()

                ContentUnavailableView(
                    "No contexts",
                    systemImage: "rectangle.stack",
                    description: Text("Create your first context to get started.")
                )
            } else {
                Table(store.contexts) {
                    TableColumn("Context") { context in
                        Label(context.name, systemImage: context.symbol)
                    }
                    TableColumn("Apps") { context in
                        Text(context.applications.map { $0.displayName }.joined(separator: ", "))
                    }

                    TableColumn("Actions") { context in
                        HStack(spacing: 8) {
                            Button("Run", systemImage: "figure.run") {
                                Task {
                                    await viewModel.runContext(context)
                                }
                            }
                            .tint(.green)

                            Button("Edit", systemImage: "pencil") {
                                viewModel.presentContextEditor(context)
                            }
                            .labelStyle(.iconOnly)
                            .tint(.yellow)
                            .help("Edit context")

                            Button("Delete", systemImage: "trash", role: .destructive) {
                                Task {
                                    await viewModel.deleteContext(context)
                                }
                            }
                            .labelStyle(.iconOnly)
                            .tint(.red)
                        }
                        .disabled(interactionsDisabled)
                    }
                    .width(100)
                }
            }

            Spacer()

            HStack {
                Button("Create a new Context") {
                    viewModel.presentContextCreator()
                }
                .disabled(interactionsDisabled)

                Spacer()

                Text("Total: \(store.contexts.count)")
            }
            .sheet(
                isPresented: Binding<Bool>(
                    get: { viewModel.isCreatingOrEditing },
                    set: { isPresented in
                        if !isPresented {
                            viewModel.dismissContextCreator()
                        }
                    }
                )
            ) {
                ContextCreatorView(context: viewModel.contextBeingEdited)
            }
        }
    }
}
