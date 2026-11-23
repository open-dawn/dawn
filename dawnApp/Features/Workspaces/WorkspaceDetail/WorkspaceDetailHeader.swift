import libdawnUI
import SwiftUI

struct WorkspaceDetailHeader: View {
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
        HStack(spacing: 10) {
            Label {
                Text(name)
                    .font(DawnTextStyle.detailTitle)
                    .dawnZainOpticalAlignment()
                    .foregroundStyle(DawnColors.primaryForeground)
                    .lineLimit(1)
            } icon: {
                Image(systemName: symbol)
                    .font(DawnTextStyle.detailTitle)
                    .contentTransition(.symbolEffect)
            }
            .animation(.spring, value: symbol)

            Spacer(minLength: 0)

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
                    DButton(style: .detailPrimary) {
                        onActivate()
                    } content: {
                        Text("Start")
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
                Image(systemName: "ellipsis")
                    .font(DawnTextStyle.detailField)
                    .foregroundStyle(DawnColors.primaryForeground)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .fixedSize()
            .disabled(interactionsDisabled)
            .accessibilityLabel("Workspace actions")
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
    }
}
