import libdawn
import SwiftUI

struct ContextDetailView: View {
    let context: WorkspaceContext
    let viewModel: ContextDetailViewModel
    let interactionsDisabled: Bool
    let onDelete: (WorkspaceContext) -> Void

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
                    interactionsDisabled: interactionsDisabled,
                    onActivate: {
                        Task {
                            await viewModel.runContext(context)
                        }
                    }
                )

                HStack(alignment: .top, spacing: 32) {
                    ContextDetailNameField(name: editedContext.name) { newName in
                        viewModel.setName(newName)
                    }

                    ContextDetailSymbolPicker(symbol: editedContext.symbol) { newSymbol in
                        viewModel.setSymbol(newSymbol)
                    }
                }
                .padding(.horizontal, 32)

                ContextDetailApplicationList(applications: context.applications)

                ContextDetailActivationPolicyPicker()

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onChange(of: context, initial: true) { _, snapshot in
                viewModel.adopt(snapshot)
            }
        }
    }
}
