import PaEventKit
import SwiftUI

struct ContextCreatorView: View {
    @Environment(PaSettingsContextStore.self)
    private var contextStore

    private let context: WorkspaceContext?

    init(context: WorkspaceContext? = nil) {
        self.context = context
    }

    var body: some View {
        ContextCreatorContent(
            contextSaver: contextStore,
            context: context
        )
    }
}

private struct ContextCreatorContent: View {
    @State private var viewModel: ContextCreatorView.ViewModel
    @Environment(\.dismiss) private var dismiss

    init(contextSaver: any ContextSaving, context: WorkspaceContext?) {
        _viewModel = State(
            initialValue: ContextCreatorView.ViewModel(
                contextSaver: contextSaver,
                context: context
            )
        )
    }

    var body: some View {
        VStack {
            Form {
                Section("Context information") {
                    TextField("Context name", text: $viewModel.context.name)
                    TextField("Icon", text: $viewModel.context.symbol)
                }

                Section("Apps to open") {
                    HStack {
                        Text("Insert a new app")
                        Spacer()
                        Button {
                            Task {
                                await viewModel.addApplication()
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .disabled(viewModel.isLoading)
                    }

                    ForEach($viewModel.context.applications, id: \.id) { $application in
                        appRow($application)
                    }
                }
            }
            .padding(16)
            .formStyle(.grouped)

            if let error = viewModel.applicationSelectionError {
                Text(error.localizedDescription)
                    .foregroundStyle(.red)
            }

            if viewModel.saveError != nil {
                Text("The context could not be saved. Check its fields and try again")
                    .foregroundStyle(.red)
            }

            Button(viewModel.isEditing ? "Save changes" : "Create the context") {
                Task {
                    if await viewModel.saveContext() {
                        dismiss()
                    }
                }
            }
            .disabled(viewModel.isLoading)
            .padding(.bottom, 35)
        }
    }

    @ViewBuilder
    private func appRow(_ app: Binding<WorkspaceApplication>) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(app.wrappedValue.displayName)

                Text(app.wrappedValue.bundleIdentifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle(
                "New instance",
                isOn: app.createNewInstance
            )
            .toggleStyle(.checkbox)

            Button(
                "Delete \(app.wrappedValue.displayName)",
                systemImage: "trash",
                role: .destructive
            ) {
                viewModel.removeApp(app.wrappedValue.id)
            }
            .tint(.red)
            .labelStyle(.iconOnly)
        }
    }
}
