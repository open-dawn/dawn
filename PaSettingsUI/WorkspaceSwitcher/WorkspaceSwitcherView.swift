import SwiftUI

struct WorkspaceSwitcherView: View {
    @State private var viewModel = Self.ViewModel()

    var body: some View {
        VStack {
            Table(viewModel.contexts) {
                TableColumn("Context") { context in
                    Label(context.name, systemImage: context.symbol)
                }
                TableColumn("Apps") { context in
                    Text(context.applications.map { $0.displayName }.joined(separator: ", "))
                }

                TableColumn("Actions") { context in
                    HStack(spacing: 8) {
                        Button("Run", systemImage: "figure.run") { viewModel.runContext(context) }
                            .tint(.green)

                        Button("Edit", systemImage: "pencil") { viewModel.editContext(context) }
                            .labelStyle(.iconOnly)
                            .tint(.yellow)

                        Button("Delete", systemImage: "trash", role: .destructive) { viewModel.deleteContext(context) }
                            .labelStyle(.iconOnly)
                            .tint(.red)
                    }
                }
                .width(100)
            }

            HStack {
                Button("Create a new Context") {
                    viewModel.createContext()
                }

                Spacer()

                Text("Total: \(viewModel.contexts.count), In use: \(viewModel.contextActive?.name ?? "...")")
            }
            .sheet(isPresented: Binding<Bool>(
                get: { viewModel.isCreatingOrEditing },
                set: { _ in viewModel.cancelCreateContext() }
            )) {
                ContextCreatorView()
            }
        }
    }
}
