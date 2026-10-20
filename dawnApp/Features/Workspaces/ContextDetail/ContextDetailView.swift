import libdawn
import SwiftUI

struct ContextDetailView: View {
    let context: WorkspaceContext
    let viewModel: ViewModel
    let interactionsDisabled: Bool
    let onDelete: (WorkspaceContext) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(context.name, systemImage: context.symbol)
                .font(.title2)

            if context.applications.isEmpty {
                Text("No apps in this context.")
                    .foregroundStyle(.secondary)
            } else {
                Text(context.applications.map { $0.displayName }.joined(separator: ", "))
                    .foregroundStyle(.secondary)
            }

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
                .tint(.yellow)
                .help("Edit context")

                Button("Delete", systemImage: "trash", role: .destructive) {
                    Task {
                        await viewModel.deleteContext(context)

                        if viewModel.error == nil {
                            onDelete(context)
                        }
                    }
                }
                .tint(.red)
            }
            .disabled(interactionsDisabled)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
