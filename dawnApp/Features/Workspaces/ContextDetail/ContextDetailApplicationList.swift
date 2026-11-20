import libdawn
import libdawnUI
import SwiftUI

struct ContextDetailApplicationList: View {
    var title: String = "Applications"
    let applications: [WorkspaceApplication]
    let interactionsDisabled: Bool
    var horizontalPadding: CGFloat = 32
    let onAddApplications: () -> Void
    let onRemoveApplication: (WorkspaceApplication) -> Void
    let onDropApplications: ([URL]) -> Bool

    @State private var isDropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(DawnTextStyle.detailSectionLabel)
                .foregroundStyle(DawnColors.primaryForeground)

            FlowLayout(spacing: 8) {
                ForEach(applications) { app in
                    HStack(spacing: 8) {
                        if let appPath = app.applicationURL?.path(percentEncoded: false) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: appPath))
                                .resizable()
                                .frame(width: 22, height: 22)
                        } else {
                            Image(systemName: "questionmark.square")
                                .frame(width: 22, height: 22)
                        }

                        Text(app.displayName)
                            .font(DawnTextStyle.detailField)
                            .foregroundStyle(DawnColors.primaryForeground)
                            .lineLimit(1)

                        DButton(style: .plain) {
                            onRemoveApplication(app)
                        } content: {
                            Image(systemName: "xmark")
                                .font(DawnTextStyle.detailField)
                                .foregroundStyle(DawnColors.primaryForeground)
                        }
                        .disabled(interactionsDisabled)
                        .accessibilityLabel("Remove \(app.displayName)")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background {
                        DawnColors.activationPolicyBackground
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                addButton

                if applications.isEmpty {
                    Text("Nothing selected yet")
                        .font(DawnTextStyle.detailSupporting)
                        .foregroundStyle(DawnColors.activationPolicyDescription)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, horizontalPadding)
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(DawnColors.contextCardHoveredBorder, lineWidth: 1)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard !interactionsDisabled else {
                return false
            }
            return onDropApplications(urls)
        } isTargeted: { isTargeted in
            isDropTargeted = isTargeted && !interactionsDisabled
        }
    }

    private var addButton: some View {
        DButton(style: .plain) {
            onAddApplications()
        } content: {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(DawnColors.primaryForeground)
                .frame(width: 30)
                .padding(.vertical, 8)
                .background {
                    DawnColors.activationPolicyBackground
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .disabled(interactionsDisabled)
        .accessibilityLabel("Add application")
    }
}
