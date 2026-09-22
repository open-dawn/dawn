import SwiftUI
import PaEventKit

struct ContextCreatorView: View {
    @State private var viewModel: ViewModel = Self.ViewModel()
    @Environment(\.dismiss) private var dismiss

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
                        Button("Add a new context") { viewModel.addNewDefaultApp() }
                    }

                    ForEach($viewModel.context.applications, id: \.id) { $application in
                        appRow($application)
                    }
                }
            }
            .padding(16)
            .formStyle(.grouped)

            Button("Create the context") {
                viewModel.saveContext()
                dismiss()
            }
        }
    }

    @ViewBuilder
    private func appRow(_ app: Binding<WorkspaceApplication>) -> some View {
        HStack {
            TextField("App name", text: app.displayName)
            Button("Delete \(app.wrappedValue.displayName)", systemImage: "trash", role: .destructive) {
                viewModel.removeApp(app.wrappedValue.id)
            }
            .tint(.red)
            .labelStyle(.iconOnly)
        }
    }
}
