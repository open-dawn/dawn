import libdawn
import libdawnUI
import SwiftUI

struct SidebarWorkspaceList: View {
    let content: SidebarContent
    @Binding var selectedDestination: SidebarDestination?
    @Binding var isArchivedSectionExpanded: Bool
    let searchText: String

    private let activityTextFormatter = WorkspaceActivityTextFormatter()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: SidebarMetrics.listSpacing) {
                    workspaceHeader
                    workspaceRows(relativeTo: timeline.date)

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
        content.busyWorkspaceID == nil
    }

    private var workspaceHeader: some View {
        Text("Your workspaces")
            .font(DawnTextStyle.sidebarSectionHeader)
            .dawnZainOpticalAlignment()
            .foregroundStyle(DawnColors.sidebarForeground)
            .padding(.bottom, 0)
    }

    @ViewBuilder
    private func workspaceRows(relativeTo now: Date) -> some View {
        if content.isLoading && content.workspaces.isEmpty {
            statusRow(title: "Loading workspaces...", showsProgress: true)
        } else if content.workspaces.isEmpty {
            statusRow(title: "No workspaces", showsProgress: false)
        } else if filteredWorkspaces.isEmpty {
            statusRow(
                title: "No workspaces matching \"\(searchText)\"",
                showsProgress: false
            )
        } else {
            ForEach(filteredWorkspaces) { workspace in
                row(for: workspace, relativeTo: now)
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
                    .dawnZainOpticalAlignment()
                    .foregroundStyle(DawnColors.sidebarForeground)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.top, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Archived workspaces")
        .accessibilityValue("\(content.archivedWorkspaces.count)")
        .accessibilityHint(showsArchivedItems ? "Expanded" : "Collapsed")
    }

    @ViewBuilder
    private func archivedRows(relativeTo now: Date) -> some View {
        if filteredArchivedWorkspaces.isEmpty {
            let title = isSearching
                ? "No archived workspaces found"
                : "No archived workspaces"
            statusRow(title: title, showsProgress: false)
        } else {
            ForEach(filteredArchivedWorkspaces) { workspace in
                row(for: workspace, relativeTo: now)
            }
        }
    }

    private var filteredWorkspaces: [Workspace] {
        WorkspaceSearchFilter.filter(content.workspaces, searchText: searchText)
    }

    private var filteredArchivedWorkspaces: [Workspace] {
        WorkspaceSearchFilter.filter(content.archivedWorkspaces, searchText: searchText)
    }

    private func row(for workspace: Workspace, relativeTo now: Date) -> some View {
        let isLoading = content.busyWorkspaceID == workspace.id
        let isEnabled = rowsEnabled || isLoading
        let isActive = content.activeWorkspaceID == workspace.id

        return Button {
            selectedDestination = .workspace(workspace.id)
        } label: {
            SidebarWorkspaceRow(
                name: workspace.name,
                symbol: workspace.symbol,
                state: SidebarRowState(
                    isSelected: selectedDestination == .workspace(workspace.id),
                    isActive: isActive,
                    isLoading: isLoading,
                    isEnabled: isEnabled,
                    activityText: activityText(
                        for: workspace,
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
        for workspace: Workspace,
        isActive: Bool,
        relativeTo now: Date
    ) -> String {
        activityTextFormatter.sidebarActivityText(
            isActive: isActive,
            activeSince: isActive ? content.activity.activeSince : nil,
            lastUsedAt: content.activity.lastActiveAt(for: workspace.id),
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
