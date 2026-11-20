import libdawn
import libdawnUI
import SwiftUI

struct ContextDetailApplicationList: View {
    var title: String = "Applications"
    var subtitle: String?
    var titleFont: Font = DawnTextStyle.detailSectionLabel
    var titleColor: Color = DawnColors.primaryForeground
    var fillsAvailableWidth: Bool = false
    let applications: [WorkspaceApplication]
    let interactionsDisabled: Bool
    var horizontalPadding: CGFloat = 32
    let onAddApplications: () -> Void
    let onRemoveApplication: (WorkspaceApplication) -> Void
    let onDropApplications: ([URL]) -> Bool

    @State private var isDropTargeted = false

    private var rowFont: Font {
        fillsAvailableWidth ? DawnTextStyle.primary : DawnTextStyle.detailField
    }

    private var iconSize: CGFloat {
        fillsAvailableWidth ? 28 : 22
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            titleLabel

            if fillsAvailableWidth {
                fullWidthApplicationList
            } else {
                flowingApplicationList
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

    private var fullWidthApplicationList: some View {
        VStack(alignment: .leading, spacing: 8) {
            if applications.isEmpty {
                HStack(alignment: .center, spacing: 8) {
                    addApplicationButton
                        .fixedSize(horizontal: true, vertical: false)

                    emptyStateLabel
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(Array(gridRows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 8) {
                        ForEach(row) { item in
                            switch item {
                            case .application:
                                gridCell(for: item)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            case .add:
                                gridCell(for: item)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private enum GridItemModel: Identifiable {
        case application(WorkspaceApplication)
        case add

        var id: String {
            switch self {
            case let .application(application):
                application.id.uuidString
            case .add:
                "add-application"
            }
        }
    }

    private var gridRows: [[GridItemModel]] {
        let items = applications.map(GridItemModel.application) + [.add]
        var rows: [[GridItemModel]] = []
        var currentRow: [GridItemModel] = []

        for item in items {
            currentRow.append(item)
            if currentRow.count == 3 {
                rows.append(currentRow)
                currentRow = []
            }
        }

        if !currentRow.isEmpty {
            rows.append(currentRow)
        }

        return rows
    }

    @ViewBuilder
    private func gridCell(for item: GridItemModel) -> some View {
        switch item {
        case let .application(application):
            applicationRow(application)
        case .add:
            addApplicationButton
        }
    }

    private var flowingApplicationList: some View {
        FlowLayout(spacing: 8) {
            ForEach(applications) { app in
                applicationRow(app)
                    .frame(minWidth: 150, alignment: .leading)
            }

            addApplicationButton

            if applications.isEmpty {
                emptyStateLabel
                    .padding(.vertical, 0)
            }
        }
    }

    private func applicationRow(_ app: WorkspaceApplication) -> some View {
        HStack(spacing: 8) {
            applicationIcon(for: app)
                .frame(width: iconSize, height: iconSize)

            Text(app.displayName)
                .font(rowFont)
                .foregroundStyle(DawnColors.primaryForeground)
                .lineLimit(1)

            Spacer(minLength: 8)

            DButton(style: .plain) {
                onRemoveApplication(app)
            } content: {
                Image(systemName: "xmark")
                    .font(rowFont)
                    .foregroundStyle(DawnColors.primaryForeground)
                    .frame(width: 24, height: 24)
            }
            .disabled(interactionsDisabled)
            .accessibilityLabel("Remove \(app.displayName)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            fillsAvailableWidth
                ? DawnColors.contextCardBackground
                : DawnColors.activationPolicyBackground
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var addApplicationButton: some View {
        DButton(style: .plain) {
            onAddApplications()
        } content: {
            Image(systemName: "plus")
                .font(fillsAvailableWidth ? DawnTextStyle.primaryBold : DawnTextStyle.captionBold)
                .foregroundStyle(DawnColors.primaryForeground)
                .frame(
                    width: fillsAvailableWidth ? 44 : 30,
                    height: fillsAvailableWidth ? 44 : nil
                )
                .padding(.vertical, fillsAvailableWidth ? 0 : 8)
                .background {
                    fillsAvailableWidth
                        ? DawnColors.contextCardBackground
                        : DawnColors.activationPolicyBackground
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .disabled(interactionsDisabled)
        .accessibilityLabel("Add application")
    }
    private var emptyStateLabel: some View {
        Text(
            fillsAvailableWidth
                ? "Nothing selected yet. Click the 􀅼 button or drag an app here to add it."
                : "Nothing selected yet"
        )
            .font(rowFont)
            .foregroundStyle(
                fillsAvailableWidth
                    ? DawnColors.secondaryForeground
                    : DawnColors.activationPolicyDescription
            )
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func applicationIcon(for app: WorkspaceApplication) -> some View {
        if let appPath = app.applicationURL?.path(percentEncoded: false) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: appPath))
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        } else {
            Image(systemName: "questionmark.square")
                .font(DawnTextStyle.actionIcon)
                .foregroundStyle(DawnColors.primaryForeground)
        }
    }

    @ViewBuilder
    private var titleLabel: some View {
        if let subtitle, !subtitle.isEmpty {
            Text(title)
                .font(titleFont)
                .foregroundStyle(titleColor)
                + Text(" \(subtitle)")
                .font(DawnTextStyle.primary)
                .foregroundStyle(DawnColors.secondaryForeground)

        } else {
            Text(title)
                .font(titleFont)
                .foregroundStyle(titleColor)
        }
    }
}
