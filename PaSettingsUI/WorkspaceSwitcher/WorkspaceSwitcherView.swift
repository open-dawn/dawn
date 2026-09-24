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

                        Button("Edit", systemImage: "pencil") {}
                            .labelStyle(.iconOnly)
                            .tint(.yellow)
                            .disabled(true)
                            .help("Context editing is not available yet")

                        Button("Delete", systemImage: "trash", role: .destructive) {
                            Task {
                                await viewModel.deleteContext(context)
                            }
                        }
                        .labelStyle(.iconOnly)
                        .tint(.red)
                    }
                    .disabled(viewModel.operationInProgress != nil)
                }
                .width(100)
            }

            HStack {
                Button("Create a new Context") {
                    viewModel.presentContextCreator()
                }

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
                ContextCreatorView()
            }
        }
    }
}
