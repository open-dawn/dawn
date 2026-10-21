import libdawn
import libdawnUI
import SwiftUI

struct SidebarContextList: View {
    let content: SidebarContent
    @Binding var selectedDestination: SidebarDestination?
    @Binding var isArchivedSectionExpanded: Bool
    let searchText: String
    let onCreateContext: () -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                contextHeader
                contextRows

                archivedHeader

                if showsArchivedItems {
                    archivedRows
                }
            }
            .padding(.horizontal, SidebarMetrics.horizontalPadding)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        HStack(spacing: 8) {
            Text("Contexts")
                .font(DawnTextStyle.sidebarSectionHeader)
                .foregroundStyle(DawnColors.sidebarForeground)

            Spacer(minLength: 8)

            Button(action: onCreateContext) {
                Image(systemName: "plus")
                    .font(DawnTextStyle.sidebarIcon)
                    .foregroundStyle(DawnColors.sidebarIcon)
                    .frame(width: SidebarMetrics.iconSize, height: SidebarMetrics.iconSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(content.interactionsDisabled)
            .help("Create a new context")
            .accessibilityLabel("Create a new context")
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    @ViewBuilder
    private var contextRows: some View {
        if content.isLoading && content.contexts.isEmpty {
            statusRow(title: "Loading contexts...", showsProgress: true)
        } else if content.contexts.isEmpty {
            statusRow(title: "No contexts", showsProgress: false)
        } else if filteredContexts.isEmpty {
            statusRow(
                title: "No contexts matching \"\(searchText)\"",
                showsProgress: false
            )
        } else {
            ForEach(filteredContexts) { context in
                row(for: context)
            }
        }
    }

    private var archivedHeader: some View {
        Button(action: toggleArchivedSection) {
            HStack(spacing: 4) {
                Image(systemName: showsArchivedItems ? "chevron.up" : "chevron.right")
                    .font(DawnTextStyle.sidebarChevron)
                    .foregroundStyle(DawnColors.sidebarIcon)
                    .frame(width: 12, height: 12)

                Text("Archived contexts (\(content.archivedContexts.count))")
                    .font(DawnTextStyle.sidebarSectionHeader)
                    .foregroundStyle(DawnColors.sidebarForeground)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.top, 10)
            .padding(.bottom, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Archived contexts")
        .accessibilityValue("\(content.archivedContexts.count)")
        .accessibilityHint(showsArchivedItems ? "Expanded" : "Collapsed")
    }

    @ViewBuilder
    private var archivedRows: some View {
        if filteredArchivedContexts.isEmpty {
            let title = isSearching
                ? "No archived contexts found"
                : "No archived contexts"
            statusRow(title: title, showsProgress: false)
        } else {
            ForEach(filteredArchivedContexts) { context in
                row(for: context)
            }
        }
    }

    private var filteredContexts: [WorkspaceContext] {
        ContextSearchFilter.filter(content.contexts, searchText: searchText)
    }

    private var filteredArchivedContexts: [WorkspaceContext] {
        ContextSearchFilter.filter(content.archivedContexts, searchText: searchText)
    }

    private func row(for context: WorkspaceContext) -> some View {
        let isLoading = content.busyContextID == context.id
        let isEnabled = rowsEnabled || isLoading

        return Button {
            selectedDestination = .context(context.id)
        } label: {
            SidebarContextRow(
                name: context.name,
                symbol: context.symbol,
                state: SidebarRowState(
                    isSelected: selectedDestination == .context(context.id),
                    isActive: content.activeContextID == context.id,
                    isLoading: isLoading,
                    isEnabled: isEnabled
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private func statusRow(title: String, showsProgress: Bool) -> some View {
        HStack(spacing: 8) {
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
            }

            Text(title)
                .font(DawnTextStyle.sidebarMeta)
                .foregroundStyle(DawnColors.sidebarSecondaryForeground)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private func toggleArchivedSection() {
        isArchivedSectionExpanded = !showsArchivedItems
    }
}
