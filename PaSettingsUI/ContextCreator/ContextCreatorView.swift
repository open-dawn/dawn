import SwiftUI

struct ContextCreatorView: View {
    @State private var vm: ViewModel = Self.ViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Form {
                Section("Context information") {
                    TextField("Context name", text: $vm.context.name)
                    TextField("Icon", text: $vm.context.icon)
                }

                Section("Apps to open") {
                    HStack {
                        Text("Insert a new app")
                        Spacer()
                        Button("Add a new context") { vm.addNewDefaultApp() }
                    }

                    ForEach($vm.context.apps, id: \.id) { $app in
                        appRow($app)
                    }
                }
            }
            .padding(16)
            .formStyle(.grouped)

            Button("Create the context") {
                vm.saveContext()
                dismiss()
            }
        }
    }

    @ViewBuilder
    private func appRow(_ app: Binding<ContextApp>) -> some View {
        HStack {
            TextField("App name", text: app.name)
            Button("Delete \(app.wrappedValue.name)", systemImage: "trash", role: .destructive) {
                vm.removeApp(app.wrappedValue.id)
            }
            .tint(.red)
            .labelStyle(.iconOnly)
        }
    }
}
