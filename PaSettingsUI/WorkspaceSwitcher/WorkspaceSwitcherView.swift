import SwiftUI

struct WorkspaceSwitcherView: View {
    @State private var vm = Self.ViewModel()

    var body: some View {
        VStack {
            Table(vm.contexts) {
                TableColumn("Context") { context in
                    Label(context.name, systemImage: context.icon)
                }
                TableColumn("Apps") { context in
                    Text(context.apps.map{ $0.name }.joined(separator: ", "))
                }

                TableColumn("Actions") { context in
                    HStack(spacing: 8) {
                        Button("Run", systemImage: "figure.run") { vm.runContext(context) }
                            .tint(.green)

                        Button("Edit", systemImage: "pencil") { vm.editContext(context) }
                            .labelStyle(.iconOnly)
                            .tint(.yellow)

                        Button("Delete", systemImage: "trash", role: .destructive)  { vm.deleteContext(context) }
                            .labelStyle(.iconOnly)
                            .tint(.red)
                    }
                }
                .width(100)
            }

            HStack {
                Button("Create a new Context") {
                    vm.createContext()
                }

                Spacer()

                Text("Total: \(vm.contexts.count), In use: \(vm.contextActive?.name ?? "...")")
            }
            .sheet(isPresented: Binding<Bool>(
                get: { vm.isCreatingOrEditing },
                set: { _ in vm.cancelCreateContext() }
            )) {
                ContextCreatorView()
            }
        }
    }
}
