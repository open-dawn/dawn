import libdawn
import libdawnUI
import SwiftUI

struct SidebarContextList: View {
    let content: SidebarContent
    @Binding var selectedDestination: SidebarDestination?
    @Binding var isArchivedSectionExpanded: Bool
    let searchText: String

    private let activityTextFormatter = WorkspaceActivityTextFormatter()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: SidebarMetrics.listSpacing) {
                    contextHeader
                    contextRows(relativeTo: timeline.date)

                    archivedHeader

                    if showsArchivedItems {
                        archivedRows(relativeTo: timeline.date)
                    }
                }
                .padding(.horizontal, SidebarMetrics.horizontalPadding)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var showsArchivedItems: Bool {
        isArchivedSectionExpanded || isSearching
    }

    private var rowsEnabled: Bool {
        content.busyContextID == nil
    }

    private var contextHeader: some View {
        Text("Your workspaces")
            .font(DawnTextStyle.sidebarSectionHeader)
            .foregroundStyle(DawnColors.sidebarForeground)
            .padding(.bottom, 0)
    }

    @ViewBuilder
    private func contextRows(relativeTo now: Date) -> some View {
        if content.isLoading && content.contexts.isEmpty {
            statusRow(title: "Loading workspaces...", showsProgress: true)
        } else if content.contexts.isEmpty {
            statusRow(title: "No workspaces", showsProgress: false)
        } else if filteredContexts.isEmpty {
            statusRow(
                title: "No workspaces matching \"\(searchText)\"",
                showsProgress: false
            )
        } else {
            ForEach(filteredContexts) { context in
                row(for: context, relativeTo: now)
            }
        }
    }

    private var archivedHeader: some View {
        Button(action: toggleArchivedSection) {
            HStack(spacing: 4) {
                Image(systemName: showsArchivedItems ? "chevron.up" : "chevron.right")
                    .font(DawnTextStyle.sidebarChevron)
                    .foregroundStyle(DawnColors.sidebarIcon)

                Text("Archived workspaces")
                    .font(DawnTextStyle.sidebarSectionHeader)
                    .foregroundStyle(DawnColors.sidebarForeground)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.top, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Archived workspaces")
        .accessibilityValue("\(content.archivedContexts.count)")
        .accessibilityHint(showsArchivedItems ? "Expanded" : "Collapsed")
    }

    @ViewBuilder
    private func archivedRows(relativeTo now: Date) -> some View {
        if filteredArchivedContexts.isEmpty {
            let title = isSearching
                ? "No archived workspaces found"
                : "No archived workspaces"
            statusRow(title: title, showsProgress: false)
        } else {
            ForEach(filteredArchivedContexts) { context in
                row(for: context, relativeTo: now)
            }
        }
    }

    private var filteredContexts: [WorkspaceContext] {
        ContextSearchFilter.filter(content.contexts, searchText: searchText)
    }

    private var filteredArchivedContexts: [WorkspaceContext] {
        ContextSearchFilter.filter(content.archivedContexts, searchText: searchText)
    }

    private func row(for context: WorkspaceContext, relativeTo now: Date) -> some View {
        let isLoading = content.busyContextID == context.id
        let isEnabled = rowsEnabled || isLoading
        let isActive = content.activeContextID == context.id

        return Button {
            selectedDestination = .context(context.id)
        } label: {
            SidebarContextRow(
                name: context.name,
                symbol: context.symbol,
                state: SidebarRowState(
                    isSelected: selectedDestination == .context(context.id),
                    isActive: isActive,
                    isLoading: isLoading,
                    isEnabled: isEnabled,
                    activityText: activityText(
                        for: context,
                        isActive: isActive,
                        relativeTo: now
                    )
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private func activityText(
        for context: WorkspaceContext,
        isActive: Bool,
        relativeTo now: Date
    ) -> String {
        activityTextFormatter.sidebarActivityText(
            isActive: isActive,
            activeSince: isActive ? content.activity.activeSince : nil,
            lastUsedAt: content.activity.lastActiveAt(for: context.id),
            relativeTo: now
        )
    }

    private func statusRow(title: String, showsProgress: Bool) -> some View {
        HStack(spacing: 8) {
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
            }

            Text(title)
                .font(DawnTextStyle.sidebarAction)
                .foregroundStyle(DawnColors.sidebarSecondaryForeground)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .accessibilityElement(children: .combine)
    }

    private func toggleArchivedSection() {
        isArchivedSectionExpanded = !showsArchivedItems
    }
}
