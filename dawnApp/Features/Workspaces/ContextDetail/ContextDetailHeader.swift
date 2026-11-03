import dawnLogging
import libdawnUI
import SwiftUI

struct ContextDetailHeader: View {
    let name: String
    let symbol: String
    let isActive: Bool
    let interactionsDisabled: Bool
    let onActivate: () -> Void
    let onDelete: () -> Void

    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        HStack(spacing: 24) {
            Label(name, systemImage: symbol)
                .contentTransition(.symbolEffect)
                .font(DawnTextStyle.screenTitle)
                .animation(.spring, value: symbol)

            Spacer()

            if isActive {
                // swiftlint:disable:next todo
                // FIXME: Stop has no action yet. There is no stop event on the agent.
                DButton(style: .danger) {
                } content: {
                    Text("Stop")
                } leading: {
                    Image(systemName: "stop.fill")
                }
                .disabled(interactionsDisabled)
            } else {
                DButton(style: .success) {
                    onActivate()
                } content: {
                    Text("Activate")
                } leading: {
                    Image(systemName: "play.fill")
                }
                .disabled(interactionsDisabled)
            }

            Menu {
                Button {
                    // PIN-172 Implement Context Archival
                    #log(
                        "Context archival is a stub",
                        level: .warning,
                        category: .userInterface
                    )
                } label: {
                    Label("Archive", systemImage: "shippingbox")
                        .labelStyle(.titleAndIcon)
                }

                Button(role: .destructive) {
                    isDeleteConfirmationPresented = true
                } label: {
                    Label("Delete", systemImage: "trash")
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(DawnColors.dangerForeground)
                }
            } label: {
                DButton(style: .icon) {
                } content: {
                    Image(systemName: "ellipsis.circle")
                }
                .allowsHitTesting(false)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .fixedSize()
            .disabled(interactionsDisabled)
            .accessibilityLabel("Context actions")
            .confirmationDialog(
                "Delete \(name)?",
                isPresented: $isDeleteConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    onDelete()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("\(name) will be permanently deleted.")
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 32)
    }
}
