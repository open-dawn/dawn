import libdawnUI
import SwiftUI

struct ContextDetailHeader: View {
    let name: String
    let symbol: String
    let isActive: Bool
    let isArchived: Bool
    let interactionsDisabled: Bool
    let onActivate: () -> Void
    let onArchive: () -> Void
    let onUnarchive: () -> Void
    let onDelete: () -> Void
    let onStop: () -> Void

    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        HStack(spacing: 24) {
            Label(name, systemImage: symbol)
                .contentTransition(.symbolEffect)
                .font(DawnTextStyle.screenTitle)
                .animation(.spring, value: symbol)

            Spacer()

            if !isArchived {
                if isActive {
                    DButton(style: .danger) {
                        onStop()
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
            }

            Menu {
                if isArchived {
                    Button(action: onUnarchive) {
                        Label("Unarchive", systemImage: "arrow.uturn.backward")
                            .labelStyle(.titleAndIcon)
                    }
                } else {
                    Button(action: onArchive) {
                        Label("Archive", systemImage: "shippingbox")
                            .labelStyle(.titleAndIcon)
                    }
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
